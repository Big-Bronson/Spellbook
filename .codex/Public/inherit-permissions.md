## Public/inherit-permissions.ps1

### What This File Does
This script repairs NTFS folder permissions by re-enabling inheritance from parent directories. It runs interactively on a local machine, asking the operator to specify a folder path, showing what explicit (non-inherited) access rules currently block inheritance, and then optionally re-enabling inheritance and stripping those explicit rules away.

### Why It Exists
When folders are copied between volumes, migrated, or manually ACL'd during troubleshooting, they often end up with inheritance disabled and explicit Allow/Deny rules that shadow the parent folder's permissions. This creates access problems that are hard to diagnose. The script provides a safe, auditable way to unblock inheritance without losing access during the transition, and gives the operator visibility into what rules will be affected before committing changes.

### What It Protects Against
The script defends against two specific failure modes: (1) the operator accidentally running it against a file instead of a folder, and (2) the folder briefly losing all access when inheritance is re-enabled because explicitly-inherited rules aren't preserved during the transition. It handles the case where inheritance is already enabled and there are no explicit rules (early exit), and it catches and explains permission errors with a hint about taking ownership via `takeown`.

### Invariants
- The target path must exist and must be a folder (not a file).
- The script must have permission to read the ACL before attempting to modify it.
- After `SetAccessRuleProtection($false, $true)` runs, at least the currently-inherited rules must still apply, even if explicit rules remain temporarily.
- The operator must explicitly confirm re-enabling inheritance by typing 'y'; any other input aborts.

### Key Patterns
**Interactive confirmation gates**: The script uses `Read-Host` twice—once to enable inheritance and once (conditionally) to remove explicit rules—so destructive changes never happen without deliberate user acknowledgment. **Transparent state listing**: Before asking for confirmation, the script displays the folder path, current inheritance status, count of explicit rules, and a detailed listing of those rules so the operator can audit what they're about to change. **LiteralPath everywhere**: The code uses `-LiteralPath` consistently to handle folder names with special characters correctly. **Graceful degradation**: Early exits occur if the path doesn't exist, isn't a folder, or is already fully inherited, avoiding unnecessary prompts.

### Change Log
- 2026-05-08: Initial commit; added inherit-permissions script for NTFS ACL inheritance reset.