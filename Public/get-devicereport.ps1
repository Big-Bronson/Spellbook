# get-devicereport.ps1
# Pulls all Intune-managed devices for the tenant. Flags devices not synced
# in 30+ days and non-compliant devices — both are actionable for helpdesk follow-up.
# Requires: Graph (DeviceManagementManagedDevices.Read.All)

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All" -ContextScope Process
}

$staleThresholdDays = 30

Write-Host "Fetching Intune managed devices..."

$devices = Get-MgDeviceManagementManagedDevice -All `
    -Property "DeviceName,UserPrincipalName,OperatingSystem,OsVersion,ComplianceState,LastSyncDateTime,ManagementState"

if ($devices.Count -eq 0) {
    Write-Host "No managed devices found." -ForegroundColor Yellow
    return
}

$today = Get-Date

$results = foreach ($device in $devices) {
    $lastSync  = $device.LastSyncDateTime
    $daysSince = if ($lastSync) { [math]::Round(($today - $lastSync).TotalDays) } else { $null }

    $flags = @()
    if (-not $lastSync -or $daysSince -ge $staleThresholdDays) {
        $flags += if ($daysSince) { "Stale ($daysSince days)" } else { "Never synced" }
    }
    # "unknown" compliance means Intune hasn't evaluated the device yet — not actionable the same way
    if ($device.ComplianceState -ne "compliant" -and $device.ComplianceState -ne "unknown") {
        $flags += "Non-compliant"
    }

    [PSCustomObject]@{
        "Device Name"      = $device.DeviceName
        "Owner UPN"        = $device.UserPrincipalName
        "OS"               = $device.OperatingSystem
        "OS Version"       = $device.OsVersion
        "Compliance"       = $device.ComplianceState
        "Management State" = $device.ManagementState
        "Last Sync"        = if ($lastSync) { $lastSync.ToString("yyyy-MM-dd") } else { "Never" }
        "Days Since Sync"  = if ($null -ne $daysSince) { $daysSince } else { "N/A" }
        "Flags"            = $flags -join "; "
    }
}

$staleCount       = ($results | Where-Object { $_."Flags" -match "Stale|Never synced" }).Count
$nonCompliantCount = ($results | Where-Object { $_."Flags" -match "Non-compliant" }).Count
$flaggedCount     = ($results | Where-Object { $_."Flags" -ne "" }).Count

Write-Host ""
Write-Host ("  {0} devices total  |  {1} stale ({2}+ days)  |  {3} non-compliant  |  {4} flagged" -f `
    $devices.Count, $staleCount, $staleThresholdDays, $nonCompliantCount, $flaggedCount) -ForegroundColor Cyan
Write-Host ""

# Flagged devices first, then clean devices alphabetically
$flagged = @($results | Where-Object { $_."Flags" -ne "" } | Sort-Object "Flags", "Device Name")
$clean   = @($results | Where-Object { $_."Flags" -eq "" } | Sort-Object "Device Name")
($flagged + $clean) | Format-Table -AutoSize

$path = "$env:USERPROFILE\Desktop\DeviceReport_$(Get-Date -Format 'yyyyMMdd').csv"
$results | Export-Csv -Path $path -NoTypeInformation
Write-Host "Exported to $path" -ForegroundColor Cyan
