# set-autoexpand.ps1
# Enables auto-expanding archive on a mailbox.
# Note: this is a one-way switch — it cannot be disabled once turned on.
# Requires: Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false -DisableWAM }

$identity = Read-Host "Mailbox (UPN or primary SMTP)"

try {
    $mbx = Get-Mailbox -Identity $identity -ErrorAction Stop
} catch {
    Write-Host "Mailbox not found: $identity" -ForegroundColor Red
    return
}

Write-Host ""
Write-Host "  $($mbx.DisplayName) [$($mbx.PrimarySmtpAddress)]" -ForegroundColor Cyan

if ($mbx.ArchiveStatus -ne 'Active') {
    Write-Host "  Archive is not enabled on this mailbox." -ForegroundColor Red
    Write-Host "  Enable in-place archive first before turning on auto-expand." -ForegroundColor DarkGray
    return
}

if ($mbx.AutoExpandingArchiveEnabled) {
    Write-Host "  Auto-expanding archive is already enabled." -ForegroundColor DarkGray
    return
}

Write-Host "  Archive: Active   Auto-expand: Disabled" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Note: auto-expanding archive cannot be disabled once turned on." -ForegroundColor Yellow
Write-Host ""
if ((Read-Host "  Enable? (y/n)") -ne "y") { Write-Host "  Aborted." -ForegroundColor Red; return }

try {
    Set-Mailbox -Identity $mbx.PrimarySmtpAddress -AutoExpandingArchive -ErrorAction Stop
    Write-Host "  [OK] Auto-expanding archive enabled for $($mbx.PrimarySmtpAddress)" -ForegroundColor Green
} catch {
    Write-Host "  [FAILED] $_" -ForegroundColor Red
}
