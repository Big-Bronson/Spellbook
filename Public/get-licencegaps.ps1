# get-licencegaps.ps1
# Licence cost audit — finds users who hold licences but have not signed in
# within the threshold. Uses signInActivity.lastSignInDateTime (real interactive
# logins) rather than mailbox stats, which fire on received mail and produce
# false positives.
# Requires: Graph (User.Read.All, AuditLog.Read.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.Read.All", "AuditLog.Read.All" -ContextScope Process
}

$days = Read-Host "Inactivity threshold in days (default 90)"
if (-not $days) { $days = 90 }
$cutoff = (Get-Date).AddDays(-[int]$days)

Write-Host "Fetching licensed users and sign-in activity..."

# SignInActivity requires AuditLog.Read.All and must be explicitly named
# in the -Property list — it is not returned by default.
$allUsers = Get-MgUser -All `
    -Property "DisplayName,UserPrincipalName,AccountEnabled,AssignedLicenses,SignInActivity" |
    Where-Object { $_.AccountEnabled -eq $true -and $_.AssignedLicenses.Count -gt 0 }

Write-Host "$($allUsers.Count) licensed users found. Analysing sign-in activity..."

# Build a SkuId → PartNumber lookup so licence names are readable in the export.
$skuMap = @{}
Get-MgSubscribedSku | ForEach-Object { $skuMap[$_.SkuId] = $_.SkuPartNumber }

$today = Get-Date

$gaps = foreach ($user in $allUsers) {
    $lastSignIn = $user.SignInActivity.LastSignInDateTime

    $isGap = (-not $lastSignIn) -or ($lastSignIn -lt $cutoff)
    if (-not $isGap) { continue }

    $daysSince = if ($lastSignIn) {
        [math]::Round(($today - $lastSignIn).TotalDays)
    } else {
        $null
    }

    $licenceNames = ($user.AssignedLicenses | ForEach-Object {
        if ($skuMap.ContainsKey($_.SkuId)) { $skuMap[$_.SkuId] } else { $_.SkuId }
    }) -join ", "

    [PSCustomObject]@{
        "Display Name"       = $user.DisplayName
        "UPN"                = $user.UserPrincipalName
        "Assigned Licences"  = $licenceNames
        "Last Sign-In"       = if ($lastSignIn) { $lastSignIn.ToString("yyyy-MM-dd") } else { "Never" }
        "Days Since Sign-In" = if ($null -ne $daysSince) { $daysSince } else { "Never signed in" }
    }
}

# Never-signed-in users are the highest priority — surface them first, then
# sort remaining rows by days descending so the longest-inactive are at the top.
$neverSignedIn = @($gaps | Where-Object { $_."Last Sign-In" -eq "Never" })
$inactive      = @($gaps | Where-Object { $_."Last Sign-In" -ne "Never" } |
    Sort-Object { [int]$_."Days Since Sign-In" } -Descending)
$sorted = $neverSignedIn + $inactive

Write-Host ""
Write-Host "  Licence Gap Audit — threshold: $days days" -ForegroundColor Cyan
Write-Host "  Review these accounts — each unused licence is a potential cost saving." -ForegroundColor Yellow
Write-Host ""
Write-Host ("  {0} never signed in  |  {1} inactive {2}+ days  |  {3} total" -f `
    $neverSignedIn.Count, $inactive.Count, $days, $sorted.Count) -ForegroundColor Yellow
Write-Host ""

$sorted | Format-Table -AutoSize

$path = "$env:USERPROFILE\Desktop\LicenceGaps_$(Get-Date -Format 'yyyyMMdd').csv"
$sorted | Export-Csv -Path $path -NoTypeInformation
Write-Host "Exported to $path" -ForegroundColor Cyan
