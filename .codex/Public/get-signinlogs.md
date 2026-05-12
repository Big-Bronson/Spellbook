## Public/get-signinlogs.ps1

### What This File Does
This is an interactive diagnostic script that queries Microsoft Entra ID (Azure AD) sign-in audit logs for a specific user and displays the most recent authentication events with relevant context like success/failure status, MFA method used, and conditional access decisions. It acts as a troubleshooting tool within a larger identity management toolkit.

### Why It Exists
Administrators need to investigate authentication problems—MFA failures, suspicious login patterns, access denials—without navigating the Azure portal or building custom queries. This script provides a quick command-line path to the most relevant sign-in data for a given user, with automatic permission handling and human-readable output formatting.

### What It Protects Against
The script defends against three failure modes: (1) unauthenticated Graph API calls by checking for an existing Microsoft Graph context and connecting if absent, (2) missing premium licensing by catching the exception when audit logs are unavailable and surfacing a specific guidance message, and (3) malformed or empty result sets by checking row count before attempting to render a table. It does not validate the UPN format before querying.

### Invariants
- Microsoft Graph PowerShell module must be installed and loadable.
- The executing account must have `AuditLog.Read.All` and `Directory.Read.All` Graph permissions.
- The tenant must hold Entra ID P1/P2 or Microsoft 365 Business Premium licensing for sign-in logs to be populated.
- The UPN provided must exist in the tenant (or the query will simply return zero rows).

### Key Patterns
**Defensive authentication check**: The script tests for an active Graph session and establishes one if needed, rather than failing immediately. **Computed properties in Select-Object**: Custom columns decode cryptic status codes and nested objects into human-friendly strings (e.g., error code 0 → "Success"). **Try-catch with contextual messaging**: Exceptions are caught and reframed with actionable guidance pointing to licensing or permissions rather than raw stack traces.

### Change Log
- 2026-05-07: Fix Publish.ps1 string interpolation on GUID error message
- 2026-05-07: Initial Release