## Public/get-tenantreport.ps1

### What This File Does
This script generates a point-in-time health snapshot of a Microsoft 365 tenant by querying Azure AD, Exchange Online, and service health APIs, then displays findings in a formatted report while flagging issues that warrant attention. It's designed to be run as a standalone diagnostic tool—either when onboarding a new client or as a periodic audit.

### Why It Exists
M365 administrators need a quick, structured way to spot common cost drains and security gaps without manually hunting through multiple admin portals. The script automates discovery of waste (disabled accounts with licenses, shared mailboxes assigned premium licenses), risk (users without MFA), and configuration drift (admin role bloat, stale directory syncs) in a single run.

### What It Protects Against
The script guards against silent cost waste by catching disabled-but-licensed accounts and unnecessarily-licensed shared mailboxes. It flags MFA gaps and excessive admin role membership to reduce exposure to account compromise. It detects stale AD Connect syncs (by checking sync age) to surface hybrid deployment issues. It handles both cloud-only and hybrid tenants gracefully with try-catch blocks. However, it does *not* validate that the calling user has adequate permissions—it assumes the connection was already established correctly.

### Invariants
- Exchange Online and Microsoft Graph modules must be available and importable.
- The authenticated user must hold sufficient Graph permissions (User.Read.All, Directory.Read.All, etc.) and Exchange Online permissions to query mailboxes.
- The `$report` and `$issues` lists must be initialized before any `Section` or `Row` calls, as the helper functions append to them.
- The `Row` function's `$flag` parameter must be boolean; truthy/falsy values are coerced, but the intent is strict boolean logic for highlighting.

### Key Patterns
**Dual-stream output**: The script writes formatted text to the host (screen) *and* accumulates it in a `$report` list for later export. The `Row` helper enforces this symmetry. **Issue flagging**: The `$flag` parameter in `Row` doubles as both a visual cue (yellow text) and a mechanism to populate the separate `$issues` collection, creating a filterable list of findings. **Graceful degradation**: Sections like "AD Connect sync" wrap queries in try-catch to prevent one API failure from halting the entire report. **Filter-then-loop pattern**: Most data sections (users, mailboxes, roles) fetch all objects first with Graph filters, then iterate locally to avoid repeated API calls.

### Change Log
- 2026-05-07: Fix Publish.ps1 string interpolation on GUID error message
- 2026-05-07: Initial Release