## Public/get-mfaaudit.ps1

### What This File Does
This script audits your entire Azure AD tenant to identify which users have multi-factor authentication (MFA) registered and which don't. It pulls all enabled users from Microsoft Graph, queries their authentication methods, strips out password-only accounts, then generates a human-readable report and exports it to CSV for compliance tracking.

### Why It Exists
Organizations need visibility into MFA adoption before enforcing Conditional Access policies that require it. Without this script, you'd have no easy way to find the stragglers who'll break when MFA becomes mandatory, and no way to prove compliance to auditors.

### What It Protects Against
The script filters out guest accounts (those with `#EXT#` in their UPN) to avoid noise and permission issues. It also excludes password authentication methods from the "MFA Methods" count since passwords alone don't constitute MFA—this prevents false positives where a user appears to have MFA when they really don't.

### Invariants
- Microsoft Graph PowerShell module must be installed and the caller must have `User.Read.All` and `UserAuthenticationMethod.Read.All` permissions
- The script assumes `$env:USERPROFILE\Desktop` exists and is writable
- Each user's `Id` property must be valid to query authentication methods; if not, the script will fail on that user

### Key Patterns
**Lazy connection**: The script checks if a Graph context already exists before connecting, avoiding unnecessary re-authentication. **Pipeline filtering**: External accounts are filtered early to reduce downstream API calls. **Object transformation**: The script converts raw Graph OData type strings (like `#microsoft.graph.fido2AuthenticationMethod`) into readable names by stripping prefixes and suffixes. **Dual output**: Results are displayed in the console *and* exported to timestamped CSV, supporting both immediate review and audit trails.

### Change Log
- 2026-05-07: Fix Publish.ps1 string interpolation on GUID error message
- 2026-05-07: Initial Release