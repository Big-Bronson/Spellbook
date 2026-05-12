## Public/get-sharedmailboxaudit.ps1

### What This File Does
This script performs a compliance and cost audit of shared mailboxes in an Exchange Online tenant, collecting their delegated user access, storage size, and licensing status, then outputs results to both the console and a timestamped CSV file on the user's desktop.

### Why It Exists
Shared mailboxes are frequently left with unnecessary licenses (shared mailboxes don't require user licenses) and their access permissions drift over time as people are offboarded. Organizations need a simple, repeatable way to identify which shared mailboxes have active delegates, how much storage they consume, and which ones are incurring wasted licensing costs—particularly during quarterly reviews or after employee departures.

### What It Protects Against
The script guards against two concrete operational problems: (1) undetected license waste by checking which shared mailboxes still carry assigned licenses, and (2) orphaned access permissions by filtering explicitly for "FullAccess" rights held by real users (excluding system accounts via the `NT AUTHORITY` filter). It handles missing mailbox statistics gracefully with a fallback to "N/A" rather than failing entirely.

### Invariants
- Exchange Online connection must be available (script auto-connects if needed)
- Microsoft Graph connection with `User.Read.All` scope must be obtainable
- Each shared mailbox must have a valid `PrimarySmtpAddress` and `DisplayName`
- The user's `Desktop` folder must exist and be writable for CSV export
- Shared mailboxes queried must be queryable by their email address in both Exchange and Graph APIs

### Key Patterns
**Defensive connection initialization**: The script checks whether connections already exist before attempting to establish them, avoiding redundant authentications. **Graceful degradation**: Mailbox statistics and Graph user lookups use `-ErrorAction SilentlyContinue` to prevent a single unreachable mailbox from halting the entire audit. **Timestamp-namespaced output**: The CSV filename includes the execution date to prevent overwrites and create an audit trail.

### Change Log
- 2026-05-07: Fix Publish.ps1 string interpolation on GUID error message
- 2026-05-07: Initial Release