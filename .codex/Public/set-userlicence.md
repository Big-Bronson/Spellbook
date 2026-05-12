## Public/set-userlicence.ps1

### What This File Does
This is an interactive PowerShell script that manages Microsoft 365 licensing for a single user. It connects to Microsoft Graph, prompts for a user's email address, displays their current licenses and available SKUs with capacity remaining, then allows you to assign or remove a license through numbered menu selection.

### Why It Exists
Assigning licenses through the Graph API requires knowing SKU IDs (GUIDs), which administrators don't memorize. This script eliminates that friction by listing human-readable SKU names alongside available capacity, making license operations a simple interactive workflow instead of a manual lookup-and-API task.

### What It Protects Against
The script validates that the user exists before attempting license operations (exits cleanly if not found). It validates the SKU selection is within bounds before attempting assignment. Try-catch blocks around the actual license modification operations prevent unhandled API errors from crashing the session. It does not validate the action input (1 or 2), instead falling through to an "invalid action" message—this is loose error handling.

### Invariants
- Microsoft Graph must be available and the executing account must have User.ReadWrite.All and Directory.ReadWrite.All scopes.
- The user being queried must exist in the tenant's Azure AD.
- The selected SKU must have at least one unit available (the script shows capacity but doesn't prevent assignment if 0 are available—Graph will reject it).
- A valid user ID and SKU ID must exist for the Set-MgUserLicense call to succeed.

### Key Patterns
**Interactive CLI menu**: The script uses Read-Host for input collection and a numbered list format for SKU selection, supporting human-friendly interaction over scriptable parameters. **Lookup table**: A hashtable maps SKU IDs to human-readable part numbers, allowing display of friendly names alongside technical identifiers. **Early exit validation**: User existence and index bounds are validated immediately, returning before expensive operations are attempted.

### Change Log
- 2026-05-08: Fix script portability and password handling (#3)
- 2026-05-07: Fix Publish.ps1 string interpolation on GUID error message
- 2026-05-07: Initial Release