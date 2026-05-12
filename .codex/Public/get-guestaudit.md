## Public/get-guestaudit.ps1

### What This File Does
This script audits guest accounts in an Azure AD tenant by querying Microsoft Graph, categorizing them by invite acceptance status and activity age, then displays results in a formatted table and exports them to a timestamped CSV file on the user's Desktop. It runs as a standalone operational tool for access reviews.

### Why It Exists
Organizations need regular visibility into guest account hygiene—specifically identifying guests who never accepted invites or have gone inactive. Manual review of guest lists in the Azure portal is tedious and error-prone; this script automates the classification and export, making quarterly access reviews tractable.

### What It Protects Against
The script guards against two classes of drift:
1. **Orphaned invites**: guests in `PendingAcceptance` state (wasting a license seat or creating confused access expectations)
2. **Stale credentials**: accounts created over 90 days ago (high-risk targets for credential compromise or policy violation)

It also protects against running without Graph authentication by checking for an active `MgContext` and connecting if needed, avoiding silent failures.

### Invariants
- Microsoft Graph PowerShell SDK must be installed and functional
- The executing user must have Graph `User.Read.All` and `Directory.Read.All` permissions
- The user's Desktop directory must exist and be writable
- The `userType eq 'Guest'` filter must remain consistent with Azure AD's guest designation logic
- The 90-day cutoff is a fixed policy constant (not parameterized)

### Key Patterns
**Self-healing connection**: The script checks for an active Graph context and connects inline if absent, making it idempotent and safe to re-run. **Classification-via-notes**: Risk categorization (unanswered invite, stale, recent) is computed per-row and exposed as a `Notes` field rather than enforcing a strict risk tier, allowing humans to apply domain judgment. **Export-to-user-desktop**: Results are always saved with a date-stamped filename, creating an audit trail without requiring a database or centralized logging infrastructure.

### Change Log
- 2026-05-08: Fix script portability and password handling
- 2026-05-07: Fix Publish.ps1 string interpolation on GUID error message
- 2026-05-07: Initial Release