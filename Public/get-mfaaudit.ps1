# get-mfaaudit.ps1
# Lists ALL users and their MFA registration status.
# Flags accounts with no MFA registered — useful for compliance checks
# and cleaning up before enforcing Conditional Access policies.
# Requires: Graph (User.Read.All, UserAuthenticationMethod.Read.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.Read.All", "UserAuthenticationMethod.Read.All" -ContextScope Process
}

Write-Host "Fetching users..."
$users = Get-MgUser -All -Property "DisplayName,UserPrincipalName,AccountEnabled" |
    Where-Object { $_.UserPrincipalName -notmatch "#EXT#" }

Write-Host "Checking MFA methods for $($users.Count) users (this takes a while)..."

$results = foreach ($user in $users) {
    $methods = Get-MgUserAuthenticationMethod -UserId $user.Id |
        Where-Object { $_.OdataType -ne "#microsoft.graph.passwordAuthenticationMethod" }

    $methodNames = ($methods | ForEach-Object {
        $_.OdataType -replace '#microsoft.graph.', '' -replace 'AuthenticationMethod', ''
    }) -join ", "

    [PSCustomObject]@{
        "Display Name" = $user.DisplayName
        "UPN"          = $user.UserPrincipalName
        "Enabled"      = $user.AccountEnabled
        "MFA Methods"  = if ($methodNames) { $methodNames } else { "NONE" }
        "MFA Status"   = if ($methods.Count -gt 0) { "Registered" } else { "Not Registered" }
    }
}

$noMfa = $results | Where-Object { $_."MFA Status" -eq "Not Registered" }
Write-Host "`n$($results.Count) total users | $($noMfa.Count) without MFA`n"

$results | Sort-Object "MFA Status", "Display Name" | Format-Table -AutoSize

$path = "$env:USERPROFILE\Desktop\MFAAudit_$(Get-Date -Format 'yyyyMMdd').csv"
$results | Export-Csv -Path $path -NoTypeInformation
Write-Host "Exported to $path"
