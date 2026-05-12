## Public/disable-autocalevents.ps1

### What This File Does
This script tenant-wide disables the "Events from email" feature in Outlook across every user and shared mailbox. When disabled, Outlook stops auto-creating calendar entries from emails like flight confirmations, hotel bookings, and package notifications. The script iterates through all mailboxes via Exchange Online, applies the configuration change to each, and generates a CSV log on the operator's Desktop with per-mailbox status.

### Why It Exists
Organizations often want to prevent automatic calendar pollution from transactional emails. This requires a coordinated change across the entire tenant rather than per-user configuration. The script exists to automate what would otherwise be a tedious manual process, while providing auditability through logging.

### What It Protects Against
The script defends against accidental execution against the wrong tenant by forcing the operator to type the primary verified domain before proceeding—a typo aborts immediately. It also gracefully handles already-disabled mailboxes by marking them SKIPPED rather than failing, making re-runs idempotent and cheap. The try-catch blocks around each mailbox change prevent a single failure from halting the entire operation; failed mailboxes are logged and the script continues.

### Invariants
- Exchange Online connection must be active (or auto-establishes on first run)
- Microsoft Graph connection must be active with Organization.Read.All scope
- The tenant must have at least one verified domain marked as default
- The operator's Desktop directory must be writable (for CSV output)
- Each mailbox must have a calendar configuration object (standard assumption in Exchange)

### Key Patterns
**Defensive confirmation**: Domain typing requirement prevents blind execution against the wrong tenant—this is a deliberate friction point for a high-impact change. **Idempotent logging**: The SKIPPED status allows safe re-runs without re-disabling already-disabled mailboxes. **Per-item error isolation**: Individual mailbox failures are caught and logged without stopping the loop, maximizing coverage even when some mailboxes are inaccessible. **Progress feedback**: Write-Progress provides real-time visibility into a potentially long operation across many mailboxes. **Safe filename generation**: The primary domain is sanitized (dots replaced with underscores) and timestamped to prevent filename collisions on repeated runs.

### Change Log
- 2026-05-08: Initial commit adding disable-autocalevents command for tenant-wide Outlook event disabling with domain confirmation and per-mailbox logging.