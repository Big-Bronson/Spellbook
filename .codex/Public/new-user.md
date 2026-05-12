## Public/new-user.ps1

### What This File Does
This script is an interactive onboarding tool for Microsoft 365 that creates a new user account, optionally clones group memberships from an existing template user, and allows manual assignment to additional groups. It runs against the Microsoft Graph API and guides the operator through each step with prompts and status feedback.

### Why It Exists
M365 user creation is tedious when done manually through the admin portal, and consistency is hard to enforce—especially group membership. This script automates the repetitive parts (group copying) while keeping the human in control of core decisions (which user to create, which template to copy from). It eliminates copy-paste errors and ensures the new user starts with the correct group context immediately.

### What It Protects Against
The script defends against password exposure in memory and command history. The initial version stored the password as plain text in a variable. The current version uses `Read-Host -AsSecureString` to collect it securely, converts it to plaintext only at the moment of API use, then immediately nulls the variable in a `finally` block to ensure cleanup even if the user creation fails. This prevents the password from lingering in the PowerShell process memory or appearing in transcripts.

### Invariants
- Microsoft Graph context must be authenticated before the script runs (or the connection prompt will fire automatically).
- The Graph scopes `User.ReadWrite.All`, `Group.ReadWrite.All`, and `Directory.Read.All` must be granted to the calling principal.
- Template user and group lookups are case-sensitive exact matches against UPN and display name respectively.
- The mail nickname is derived from the UPN by splitting on `@` and taking the local part—this assumes standard UPN format.

### Key Patterns
**Template-based onboarding**: The script uses an optional template user as a source of truth for group membership, reducing manual configuration and enforcing organizational structure.

**Graceful optional steps**: Group copying and manual group addition are both optional workflows—the script prompts but doesn't fail if either is skipped.

**Per-action error handling**: Each group membership assignment is wrapped in its own try-catch, so failure adding one group doesn't stop the process for others.

**Secure credential handling**: Password input uses `Read-Host -AsSecureString` and the plain-text version is scoped tightly to the API call with immediate cleanup via `finally`.

### Change Log
- 2026-05-08: Fix script portability and password handling (#3)
- 2026-05-07: Fix Publish.ps1 string interpolation on GUID error message
- 2026-05-07: Initial Release