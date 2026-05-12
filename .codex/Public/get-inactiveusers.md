## Public/get-inactiveusers.ps1

### What This File Does
This is an interactive audit script that discovers enabled user accounts with no recent activity—either those who haven't logged in within a configurable threshold (default 90 days) or never logged in at all. It supports both on-premises Active Directory environments and cloud-only Microsoft 365 tenants, adapting its data sources and connection logic accordingly, then outputs results as a formatted table and optionally exports to CSV.

### Why It Exists
Organizations need to identify dormant accounts for security and compliance reasons: inactive accounts are attack surface, and regulatory frameworks often require periodic reviews of active accounts. The dual-path design acknowledges that enterprises run mixed environments—some on-prem AD only, some cloud-only—so a single script needed to handle both without requiring separate tools.

### What It Protects Against
The script protects against incomplete results in cloud environments by indexing mailbox statistics before querying users, preventing N+1 lookup performance issues. It guards against null reference errors by explicitly checking for missing `LastLogonDate` (on-prem) and missing mailbox activity records (cloud). It avoids case-sensitivity bugs by normalizing UPNs to lowercase before dictionary lookups. The conditional connection checks prevent redundant authentication or failures from already-connected sessions.

### Invariants
- Only enabled user accounts are considered (disabled users are filtered out).
- The cutoff date calculation must happen before the branched logic (both paths depend on `$cutoff`).
- Cloud path requires both Exchange Online and Microsoft Graph connections to exist or be established.
- On-prem path requires the ActiveDirectory module to be importable.
- UPN comparison must be case-insensitive (achieved via `.ToLower()`).
- Results are always sorted by last login date, with null values first.

### Key Patterns
**Dual-mode branching**: The script uses a simple string mode selector to completely swap implementation paths rather than trying to unify them, accepting code duplication over fragile abstraction. **Lazy connection**: Cloud connections are established only if needed, checking for existing context first. **Custom object projection**: Both paths reshape raw directory objects into a consistent output schema before filtering and sorting, keeping presentation logic separate. **Lookup table indexing**: The cloud path pre-indexes mailbox stats into a dictionary to avoid repeated cmdlet calls.

### Change Log
- 2026-05-08: Fix OrderedDictionary ContainsKey bug; add CLAUDE.md; Publish.ps1 rewrite
- 2026-05-07: Fix Publish.ps1 string interpolation on GUID error message
- 2026-05-07: Initial Release