## Public/get-groupmembers.ps1

### What This File Does
This is an interactive audit script that connects to Microsoft Graph, prompts a user for a group name, retrieves all members of that group, and displays them in a formatted table with the option to export to CSV. It's a standalone tool for administrators to quickly inspect group membership across distribution lists, security groups, and M365 groups.

### Why It Exists
Group membership auditing is a common administrative task, but querying Microsoft Graph directly requires authentication setup and API knowledge. This script wraps that complexity into a user-friendly interactive experience that handles authentication automatically on first run and provides formatted output suitable for compliance reviews and exports.

### What It Protects Against
The script defends against several failure modes: it handles cases where a group doesn't exist or multiple groups match the same name by exiting early with user feedback. It catches exceptions when trying to resolve members that aren't user objects (like service principals or mail contacts) and displays them gracefully rather than crashing. It sanitizes the group name before using it in a filename to prevent path injection attacks or filesystem errors when exporting to CSV.

### Invariants
- Microsoft Graph context must be established (either pre-existing or created on first run)
- User input for group name must match a display name exactly
- At most one group must match the provided display name
- The Microsoft Graph PowerShell SDK must be installed
- The user running the script must have Group.Read.All and User.Read.All permissions in their tenant

### Key Patterns
**Early exit on validation failure**: The script uses immediate returns when group lookup fails, preventing downstream code from executing against invalid state. **Graceful degradation**: When a member object cannot be resolved as a user, the script captures the exception and displays the raw ID with a "(non-user object)" label rather than failing entirely. **Safe filename construction**: Group names are sanitized by replacing filesystem-illegal characters before being used in export paths.

### Change Log
- 2026-05-08: Fix script portability and password handling
- 2026-05-07: Initial Release