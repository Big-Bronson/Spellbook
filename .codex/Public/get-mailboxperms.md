## Public/get-mailboxperms.ps1

### What This File Does
This is an interactive diagnostic script that audits delegated access to a single Exchange Online mailbox. It queries two permission layers—FullAccess (via `Get-MailboxPermission`) and SendAs (via `Get-RecipientPermission`)—filters out system noise, and displays the results in a human-readable format. It's designed as a point-in-time lookup tool, not a bulk reporting mechanism.

### Why It Exists
Exchange Online mailbox permissions are commonly delegated but hard to audit quickly. An administrator needs to answer "who can access this mailbox?" without wading through system accounts, SIDs, and inherited permissions. This script provides a fast, clean answer by prompting for a single mailbox identity and surfacing only the meaningful delegates.

### What It Protects Against
The script defends against noisy, unactionable results by filtering two categories of system noise: NT AUTHORITY accounts (built-in Windows principals) and S-1-5 SID prefixes (orphaned or system-generated SIDs). Without these filters, the output would be cluttered with inherited permissions that operators cannot and should not modify. It also gates execution behind an Exchange Online connection check, preventing failures if the module is not loaded.

### Invariants
- Exchange Online PowerShell module must be available and connectable (or already connected).
- The supplied mailbox identity must resolve to exactly one mailbox via `Get-Mailbox`.
- FullAccess permission records must have a `User` property; SendAs records must have a `Trustee` property.
- The script assumes `Get-MailboxPermission` and `Get-RecipientPermission` will not raise fatal errors (caught and logged instead).

### Key Patterns
**Interactive CLI input**: The script uses `Read-Host` to prompt for a mailbox identity rather than accepting pipeline or parameter input. This is a deliberate choice for single-lookup workflows.

**Dual permission-type reporting**: The script treats FullAccess and SendAs as separate concerns, each with its own query, filter, and output block. This separation mirrors how Exchange manages these permissions under the hood.

**Noise filtering by pattern match**: Rather than maintaining a hardcoded list of system principals, the script uses wildcard patterns (`-notlike`) to exclude broad categories of system noise.

**Try-catch per operation**: Each permission query is wrapped independently, so a failure in one section (e.g., SendAs query) doesn't prevent the other (e.g., FullAccess) from displaying.

### Change Log
- 2026-05-08: Initial commit adding mailbox permissions family (get-mailboxperms, get-userperms, add-mailboxperms); shows FullAccess and SendAs delegates with NT AUTHORITY/S-1-5 filtering.