# get-signinlogs.ps1
# Pulls the last N sign-in events for a user.
# Useful for: investigating MFA issues, failed logins, suspicious activity,
#             confirming a user can actually reach services.
#
# Note: Requires Entra ID P1/P2 OR Microsoft 365 Business Premium for full sign-in history.
#       Without premium licensing the log may be limited or empty.
# Requires: Graph (AuditLog.Read.All, Directory.Read.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "AuditLog.Read.All", "Directory.Read.All" -ContextScope Process
}

$upn   = Read-Host "Enter UPN"
$count = Read-Host "How many recent sign-ins to show? (default 20)"
if (-not $count) { $count = 20 }

Write-Host "`nFetching sign-in logs for $upn..."

try {
    $logs = Get-MgAuditLogSignIn -Filter "userPrincipalName eq '$upn'" -Top $count |
        Select-Object CreatedDateTime, AppDisplayName, IPAddress, Location,
                      @{N="Status"; E={ if ($_.Status.ErrorCode -eq 0) { "Success" } else { "Failed: $($_.Status.FailureReason)" } }},
                      @{N="MFA"; E={ $_.MfaDetail.AuthMethod }},
                      @{N="Conditional Access"; E={ $_.ConditionalAccessStatus }},
                      ClientAppUsed

    if ($logs.Count -eq 0) {
        Write-Host "No sign-in logs found. Tenant may not have premium licensing for this feature." -ForegroundColor Yellow
    } else {
        $logs | Format-Table -AutoSize
    }
} catch {
    Write-Host "Unable to retrieve sign-in logs. Confirm AuditLog.Read.All permission and premium licensing." -ForegroundColor Red
    Write-Host $_ -ForegroundColor DarkGray
}
