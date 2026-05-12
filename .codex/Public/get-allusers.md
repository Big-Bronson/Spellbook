## Public/get-allusers.ps1

### What This File Does
This script produces a tenant-wide user inventory report by pulling user metadata from Microsoft Graph, license assignments from subscription SKUs, and mailbox activity timestamps from Exchange Online, then displays the results as a formatted table and exports them to a CSV file on the user's Desktop.

### Why It Exists
Organizations need a simple way to audit all users in their tenant without requiring Entra ID P1 or P2 licenses. The script trades the rich activity data those premium tiers provide for a practical alternative: Exchange mailbox statistics, which are available in all Exchange Online deployments. This fills a gap for cost-conscious or licensing-constrained environments that still need visibility into who exists in the directory and when they last logged in.

### What It Protects Against
The script defends against a specific failure mode: orphaned or partially-provisioned directory accounts that lack a UPN (User Principal Name). Such accounts are rare but real—they result from failed provisioning workflows, incomplete deletions, or directory corruption. Without the null-check guard on `$user.UserPrincipalName`, the script would crash with a NullReferenceException when calling `.ToLower()` on a null value, aborting the entire export and leaving the operator with no report at all. Instead, the script surfaces these orphans in the output so they can be identified and remediated.

### Invariants
- Exchange Online and Microsoft Graph connections must be available and authenticated before execution.
- Every user returned by `Get-MgUser` must have at least a `DisplayName` field (the Graph API guarantees this).
- The SKU lookup table must exist before license decoding begins; if `Get-MgSubscribedSku` returns nothing, unlicensed users will still process correctly.
- Users without a UPN must never be dereferenced into the `$statsIndex` hashtable, or a null reference will occur.
- The CSV export path must be writable; if `$env:USERPROFILE\Desktop` is inaccessible, the export will fail silently.

### Key Patterns
**Defensive Null Checking**: The UPN guard uses the same pattern twice—once when building the `$statsIndex` hashtable and again when looking up each user—to ensure consistency and prevent orphan accounts from crashing the script.

**Lookup Table / Hashtable**: SKU IDs and mailbox stats are indexed as hashtables for O(1) lookup performance rather than repeated linear searches, improving performance as tenant size grows.

**Note Precedence**: The notes field uses an ordered if-elseif chain so that the most critical issue (missing UPN) is always reported, preventing less severe conditions (disabled account, no activity) from masking it.

**Dual Output**: Results are both displayed to console and persisted to CSV with a timestamp in the filename, supporting both immediate inspection and archival.

### Change Log
- 2026-05-11: Release 1.1.0: V2 mailflow, expanded RequiredModules, audit-log integrity
- 2026-05-07: Initial release (introduced orphan account null-check guard and dual-output pattern)