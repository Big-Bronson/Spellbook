## Public/get-userreport.ps1

### What This File Does
This is an interactive diagnostic script that generates a comprehensive snapshot of a single Azure AD user's account state. When run, it prompts for a user's UPN, then queries Microsoft Graph and Exchange Online to assemble and display account basics, license assignments, group memberships, admin roles, MFA configuration, mailbox settings, and delegated permissions—all in one formatted report. It's designed as a support tool to give you everything relevant about a user at a glance.

### Why It Exists
Support teams and administrators need fast visibility into user configurations during troubleshooting calls or before making changes. Rather than running five separate commands across different tools and mentally assembling the picture, this script bundles the essential queries together and formats the output consistently. It eliminates the manual context-switching between Graph and Exchange Online cmdlets.

### What It Protects Against
The script defends against several failure modes: it validates that both Graph and Exchange Online connections exist before proceeding; it handles the case where a queried user doesn't exist (exits gracefully with a colored error); it wraps mailbox and permission queries in try-catch blocks to prevent script failure if the user has no mailbox or access is denied; it filters out system accounts (NT AUTHORITY, SID patterns) from permission reports so you only see human-meaningful delegations; it uses `SilentlyContinue` on mailbox statistics to tolerate missing audit data without stopping execution.

### Invariants
- The executing user must hold the specified Graph scopes (User.Read.All, Directory.Read.All, UserAuthenticationMethod.Read.All) and Exchange Online permissions to read mailbox and permission data.
- The UPN provided must be a valid Azure AD user (format validation is implicit—Graph returns null if malformed or nonexistent).
- Graph and Exchange Online modules must be installed and available.
- The script operates in the caller's current PowerShell session; it does not isolate scope beyond `-ContextScope Process` for Graph.

### Key Patterns
**Connection-on-demand**: The script checks for existing connections before attempting to establish them, avoiding unnecessary re-authentication. **Lookup table for readability**: SKU IDs are stored in a hashtable so license names render as human-readable SKU part numbers rather than GUIDs. **Structured section output**: Each information category (Account, Licences, Groups, etc.) is clearly labeled with colored headers, making the report scannable. **Defensive filtering**: The permissions section uses `-notlike` patterns to exclude system identities and noise. **Try-catch for graceful degradation**: Mailbox operations can fail without killing the entire report; errors are caught and a friendly message is printed instead.

### Change Log
- 2026-05-08: Fix script portability and password handling
- 2026-05-07: Fix Publish.ps1 string interpolation on GUID error message
- 2026-05-07: Initial Release