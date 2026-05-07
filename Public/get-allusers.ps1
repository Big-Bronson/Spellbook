# get-allusers.ps1
# All users in tenancy — Display Name, UPN, Licenses, Last Mailbox Activity, Notes
# No Entra P1/P2 required. Uses Exchange mailbox stats for last activity.
# Requires: Graph (User.Read.All, Directory.Read.All) + Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline }
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All" -ContextScope Process
}

Write-Host "Fetching SKU list..."
$skus = Get-MgSubscribedSku
$skuLookup = @{}
foreach ($sku in $skus) { $skuLookup[$sku.SkuId] = $sku.SkuPartNumber }

Write-Host "Fetching users..."
$users = Get-MgUser -All -Property "DisplayName,UserPrincipalName,AssignedLicenses,AccountEnabled"

Write-Host "Fetching mailbox activity (takes a moment)..."
$mailboxStats = Get-MailboxStatistics -ResultSize Unlimited | Select-Object DisplayName, UserPrincipalName, LastLogonTime

$statsIndex = @{}
foreach ($stat in $mailboxStats) {
    if ($stat.UserPrincipalName) { $statsIndex[$stat.UserPrincipalName.ToLower()] = $stat.LastLogonTime }
}

$results = foreach ($user in $users) {
    $licenses = if ($user.AssignedLicenses.Count -gt 0) {
        ($user.AssignedLicenses.SkuId | ForEach-Object { $skuLookup[$_] }) -join ", "
    } else { "None" }

    $lastLogin = $statsIndex[$user.UserPrincipalName.ToLower()]
    $enabled   = $user.AccountEnabled

    $notes = if (-not $enabled) {
        "Account Disabled"
    } elseif (-not $lastLogin) {
        "No Mailbox Activity"
    } else {
        "Active"
    }

    [PSCustomObject]@{
        "Display Name" = $user.DisplayName
        "UPN"          = $user.UserPrincipalName
        "Enabled"      = $enabled
        "Licenses"     = $licenses
        "Last Login"   = $lastLogin
        "Notes"        = $notes
    }
}

$results | Sort-Object "Last Login" | Format-Table -AutoSize

$path = "$env:USERPROFILE\Desktop\AllUsers_$(Get-Date -Format 'yyyyMMdd').csv"
$results | Export-Csv -Path $path -NoTypeInformation
Write-Host "`nExported to $path"
