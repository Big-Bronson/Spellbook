## Public/check-mailflow.ps1

### What This File Does
This is an interactive PowerShell diagnostic script that searches Exchange Online message traces to answer "where did this email go?" questions. It prompts an operator for sender, recipient, and time-window filters; fetches matching message records using paginated API calls; displays results in a table; and optionally exports to CSV or drills down into per-hop delivery details for a single message.

### Why It Exists
Exchange Online mailflow troubleshooting requires querying the message trace API, which is not a straightforward cmdlet call—it requires authentication, pagination handling (V2 API), optional filtering, and careful result projection. Rather than require every support engineer to write or remember the pagination loop and schema conversion, this script encapsulates that knowledge into a reusable, guided tool.

### What It Protects Against
- **Pagination runaway**: unfiltered queries on busy tenants could theoretically paginate forever; the script caps at 10,000 rows and warns the operator.
- **API window rejection**: the script clamps the requested time window to the documented maximum of 168 hours (10 days) server-side rather than letting the API reject it with a generic error.
- **Missing recipient on drill-down**: the V2 detail API requires a recipient address alongside the message ID; the script looks it up from the matching result row, falling back to the originally-entered filter if that lookup fails, rather than re-prompting.
- **Connection drop**: the script checks for an active Exchange Online connection and establishes one if needed, following the ADR-0003 self-contained-connection pattern.

### Invariants
- ExchangeOnlineManagement module version 3.7.0 or later must be installed (for V2 cmdlets).
- The operator must have permission to call Get-MessageTraceV2 and Get-MessageTraceDetailV2.
- The V2 API returns result objects with `Received`, `SenderAddress`, `RecipientAddress`, `Subject`, `Status`, `ToIP`, `FromIP`, `Size`, and `MessageId` properties (or at minimum the ones used in the Select-Object calls).
- Pagination terminates when a call returns fewer than 1000 rows, when the cursor is empty, or when the result count hits 10,000.

### Key Patterns
- **Pagination cursor loop**: implements V2's `-StartingRecipientAddress` continuation pattern—fetch a page, extract the last recipient as the cursor, pass it back on the next call, stop when the page is partial.
- **Schema projection**: pipes all rows through a Select-Object statement to enforce a fixed column order and set, preserving operator muscle memory and CSV output shape despite upstream API changes.
- **Graceful degradation on drill-down**: attempts to resolve the recipient from the displayed results row but falls back to the original filter input rather than failing or re-prompting.
- **Self-contained connection**: every Public script ensures its own Exchange Online connection, decoupling it from a shared bootstrap.
- **Defensive breaking**: includes guards like `if (-not $cursor) { break }` to bail rather than loop forever on unexpected API responses.

### Change Log
- 2026-05-11: Release 1.1.0 with V2 mailflow migration, expanded RequiredModules, and audit-log integrity checks.
- 2026-05-07: Fix string interpolation in Publish.ps1 GUID error message (touched alongside this file's initial release).
- 2026-05-07: Initial release.