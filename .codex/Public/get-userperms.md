## Public/get-userperms.ps1

### What This File Does
This script audits which mailboxes in an Exchange Online tenant a specific user has been granted delegated access to. It scans every mailbox, checks for two permission types (Full Access and Send As), and reports back a categorized list of mailboxes where the target user holds either right.

### Why It Exists
Exchange Online administrators need to understand the scope of access they've granted to users—both for security audits and for cleanup when users change roles or leave the organization. Rather than check each mailbox individually, this script automates the discovery across the entire tenant, making it practical to answer "what can this person access?" in seconds instead of hours.

### What It Protects Against
The script validates that the input UPN belongs to an actual recipient before scanning begins, preventing wasted iteration over all mailboxes for a typo or nonexistent user. It also explicitly filters out deny entries when checking Full Access permissions, so that explicit denials (which override grants) are not misreported as positive access. The progress bar and upfront warning about tenant size protect operators from silent, mysterious hangs on large deployments.

### Invariants
- Exchange Online must be connected (or connectable) when the script runs.
- The input UPN must resolve to a valid recipient object, or the script exits early.
- All mailboxes in the tenant must be enumerable via `Get-Mailbox -ResultSize Unlimited`.
- Full Access and Send As are the only two permission types tracked; other delegation rights are ignored.

### Key Patterns
**Early validation**: recipient existence is checked before any expensive iteration begins. **Progress feedback**: a live progress bar keeps the operator informed during the (potentially long) mailbox scan. **Dual-list accumulation**: two separate `System.Collections.Generic.List[string]` collections isolate Full Access results from Send As results, enabling separate reporting. **Silent error suppression**: `-ErrorAction SilentlyContinue` on permission lookups allows the loop to continue even if a mailbox is temporarily unavailable or the permission query fails for one mailbox.

### Change Log
- 2026-05-08: Initial addition as part of mailbox permissions family (get-mailboxperms, get-userperms, add-mailboxperms).