## Public/get-smsmfa.ps1

### What This File Does
This script retrieves and displays all phone-based MFA methods registered to a user in Microsoft Entra ID. It connects to Microsoft Graph, looks up a user by UPN, fetches their authentication phone methods, and formats them for on-screen inspection with IDs, phone types, and numbers.

### Why It Exists
Operators need visibility into what MFA phone methods a user has configured—mobile, alternate mobile, office—to troubleshoot authentication issues, verify enrollment, or prepare for method updates or removal. This script provides the read-only query layer that sits upstream of the set/add/remove operations in the MFA toolkit.

### What It Protects Against
The script guards against three failure modes: (1) missing Graph connection—it auto-connects if needed rather than failing silently; (2) nonexistent users—it validates the UPN lookup and exits cleanly with a clear error message instead of throwing; (3) empty method lists—it gracefully reports "no methods registered" instead of returning nothing and leaving the operator confused about whether the lookup succeeded.

### Invariants
- Microsoft Graph PowerShell SDK must be installed and loadable.
- The calling identity must have `UserAuthenticationMethod.Read.All` scope.
- The user specified by UPN must exist in the tenant.
- The user object must have `Id` and `DisplayName` properties populated.

### Key Patterns
**Graceful degradation**: `-ErrorAction SilentlyContinue` on potentially failing Graph calls, with explicit validation afterward rather than trapping exceptions. **Interactive input**: `Read-Host` for UPN rather than parameters—this is a manual operator tool, not a scriptable API. **Formatted output**: Uses `Write-Host` with `-ForegroundColor` and string interpolation (`-f`) to produce a clean, readable table without piping to `Format-Table`. **Safe substring**: `$_.Id.Substring(0,8)` truncates the full method ID to a manageable display width.

### Change Log
- 2026-05-08: Initial commit—added phone MFA read operation as part of MFA family feature set.