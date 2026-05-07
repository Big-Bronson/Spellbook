# check-mailflow.ps1
# Traces message delivery for a specific sender/recipient pair within a date range.
# Useful for: "I didn't receive an email from X", "my email to Y bounced",
#             investigating spam filter blocks, connector issues.
# Requires: Exchange Online

if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline }

$sender    = Read-Host "Sender address (leave blank to skip filter)"
$recipient = Read-Host "Recipient address (leave blank to skip filter)"
$hours     = Read-Host "How many hours back to search? (default 24, max 168)"
if (-not $hours) { $hours = 24 }

$start = (Get-Date).AddHours(-[int]$hours)
$end   = Get-Date

Write-Host "`nSearching message trace ($hours hours)..."

$params = @{
    StartDate = $start
    EndDate   = $end
    PageSize  = 100
}
if ($sender)    { $params.SenderAddress    = $sender }
if ($recipient) { $params.RecipientAddress = $recipient }

$results = Get-MessageTrace @params |
    Select-Object Received, SenderAddress, RecipientAddress, Subject,
                  Status, ToIP, FromIP, Size, MessageId

if ($results.Count -eq 0) {
    Write-Host "No messages found matching those criteria." -ForegroundColor Yellow
} else {
    Write-Host "Found $($results.Count) message(s):`n"
    $results | Format-Table -AutoSize

    $export = (Read-Host "Export to CSV? (y/n)") -eq "y"
    if ($export) {
        $path = "$env:USERPROFILE\Desktop\MailTrace_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"
        $results | Export-Csv -Path $path -NoTypeInformation
        Write-Host "Exported to $path"
    }

    # Offer to drill into a specific message
    $drill = (Read-Host "`nDrill into delivery detail for a specific message? (y/n)") -eq "y"
    if ($drill) {
        $msgId = Read-Host "Paste the MessageId value"
        Get-MessageTraceDetail -MessageId $msgId -SenderAddress $sender -RecipientAddress $recipient -StartDate $start -EndDate $end |
            Select-Object Date, Event, Action, Detail | Format-Table -AutoSize
    }
}
