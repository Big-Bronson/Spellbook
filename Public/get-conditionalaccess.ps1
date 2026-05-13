# get-conditionalaccess.ps1
# Retrieves all Conditional Access policies in the tenant and exports their configuration.
# For each policy: name, state, user/group targets, app targets, grant controls.
# Requires: Graph (Policy.Read.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "Policy.Read.All" -ContextScope Process
}

Write-Host "Fetching Conditional Access policies..."

$policies = Get-MgIdentityConditionalAccessPolicy -All

if ($policies.Count -eq 0) {
    Write-Host "No Conditional Access policies found." -ForegroundColor Yellow
    return
}

Write-Host "$($policies.Count) polic$(if ($policies.Count -eq 1) {'y'} else {'ies'}) found.`n"

# Map internal state strings to readable labels
$stateMap = @{
    "enabled"                          = "Enabled"
    "disabled"                         = "Disabled"
    "enabledForReportingButNotEnforced" = "Report-only"
}

# Map grant control tokens to readable labels
$controlMap = @{
    "mfa"                    = "MFA required"
    "compliantDevice"        = "Compliant device"
    "domainJoinedDevice"     = "Domain-joined device"
    "approvedApplication"    = "Approved app"
    "compliantApplication"   = "Compliant app"
    "passwordChange"         = "Password change"
    "block"                  = "Block access"
}

$results = foreach ($policy in $policies) {

    $includeUsers  = $policy.Conditions.Users.IncludeUsers  -join ", "
    $excludeUsers  = $policy.Conditions.Users.ExcludeUsers  -join ", "
    $includeGroups = $policy.Conditions.Users.IncludeGroups -join ", "
    $excludeGroups = $policy.Conditions.Users.ExcludeGroups -join ", "

    $includeApps = $policy.Conditions.Applications.IncludeApplications -join ", "
    $excludeApps = $policy.Conditions.Applications.ExcludeApplications -join ", "

    $grantControls = if ($policy.GrantControls -and $policy.GrantControls.BuiltInControls.Count -gt 0) {
        $readable = $policy.GrantControls.BuiltInControls | ForEach-Object {
            if ($controlMap.ContainsKey($_)) { $controlMap[$_] } else { $_ }
        }
        $operator = $policy.GrantControls.Operator
        if ($readable.Count -gt 1) { "$($readable -join " $operator ") " } else { $readable[0] }
    } else {
        "None (session controls only)"
    }

    $sessionParts = @()
    if ($policy.SessionControls.SignInFrequency -and $policy.SessionControls.SignInFrequency.IsEnabled) {
        $sf = $policy.SessionControls.SignInFrequency
        $sessionParts += "SignInFrequency: $($sf.Value) $($sf.Type)"
    }
    if ($policy.SessionControls.PersistentBrowser -and $policy.SessionControls.PersistentBrowser.IsEnabled) {
        $sessionParts += "PersistentBrowser: $($policy.SessionControls.PersistentBrowser.Mode)"
    }
    if ($policy.SessionControls.CloudAppSecurity -and $policy.SessionControls.CloudAppSecurity.IsEnabled) {
        $sessionParts += "CloudAppSecurity: $($policy.SessionControls.CloudAppSecurity.CloudAppSecurityType)"
    }

    $state = if ($stateMap.ContainsKey($policy.State)) { $stateMap[$policy.State] } else { $policy.State }

    [PSCustomObject]@{
        "Policy Name"       = $policy.DisplayName
        "State"             = $state
        "Include Users"     = if ($includeUsers)  { $includeUsers }  else { "-" }
        "Exclude Users"     = if ($excludeUsers)  { $excludeUsers }  else { "-" }
        "Include Groups"    = if ($includeGroups) { $includeGroups } else { "-" }
        "Exclude Groups"    = if ($excludeGroups) { $excludeGroups } else { "-" }
        "Include Apps"      = if ($includeApps)   { $includeApps }   else { "-" }
        "Exclude Apps"      = if ($excludeApps)   { $excludeApps }   else { "-" }
        "Grant Controls"    = $grantControls
        "Session Controls"  = if ($sessionParts.Count -gt 0) { $sessionParts -join "; " } else { "-" }
    }
}

$enabled    = ($results | Where-Object { $_."State" -eq "Enabled" }).Count
$reportOnly = ($results | Where-Object { $_."State" -eq "Report-only" }).Count
$disabled   = ($results | Where-Object { $_."State" -eq "Disabled" }).Count

Write-Host "  Enabled: $enabled  |  Report-only: $reportOnly  |  Disabled: $disabled`n" -ForegroundColor Cyan

$results | Sort-Object "State", "Policy Name" | Format-Table -AutoSize

$path = "$env:USERPROFILE\Desktop\ConditionalAccess_$(Get-Date -Format 'yyyyMMdd').csv"
$results | Export-Csv -Path $path -NoTypeInformation
Write-Host "Exported to $path" -ForegroundColor Cyan
