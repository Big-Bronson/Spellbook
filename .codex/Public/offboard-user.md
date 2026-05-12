## Public/offboard-user.ps1

### What This File Does
This is an interactive PowerShell script that fully deactivates a Microsoft 365 user account in a controlled, auditable sequence. It disables sign-in, resets credentials, strips permissions, clears authentication methods, cancels meetings, converts the mailbox to shared storage, sets an out-of-office reply, removes licenses, and logs every action—success or failure—to a timestamped CSV file on the operator's Desktop.

### Why It Exists
User offboarding in M365 requires coordination across multiple services (Azure AD, Exchange, licensing) with no single built-in tool that performs all steps atomically or records them for compliance. Manual steps are error-prone and leave no audit trail. This script codifies the procedure, enforces confirmation before running, and creates an immutable record of what was attempted and what succeeded—critical for proving due diligence during terminations or security incidents.

### What It Protects Against
- **Partial failures hiding in silence**: The batch-operation pattern (visible in group removal) explicitly tracks succeeded vs. failed items rather than silently swallowing exceptions. A script that reports "removed from 5 groups" when only 3 succeeded leaves the operator unaware of what's actually still accessible to the offboarded user.
- **Password generation incompatibility**: The `New-OffboardPassword` function replaces the .NET `Membership.GeneratePassword` class, which doesn't exist in PowerShell 7 or non-Windows environments. This ensures the script works across platforms while still generating passwords that satisfy M365 complexity rules (guaranteed one uppercase, one lowercase, one digit, one symbol).
- **Accidental execution**: The script prompts for confirmation twice (once for UPN, once before proceeding) and validates the user exists before doing irreversible work.
- **Password loss**: The generated password is logged in the CSV export (which lands on the *operator's* Desktop, not the user's), preserving an audit trail without security risk.

### Invariants
- Both Graph and Exchange Online connections must be established before any operations begin.
- The user identified by UPN must exist in the tenant and be resolvable via Graph User API.
- The operator must explicitly confirm offboarding after seeing the target user's display name.
- Every operation must be logged (success, skip, or failure) before proceeding to the next step.
- The audit log must distinguish between "this operation worked" and "we tried but some sub-items failed" (e.g., removed from 3 groups but failed on 2).
- The script must terminate gracefully if the target user is not found (no partial state left behind).

### Key Patterns
- **Iterate-and-collect with honest failure tracking** (referenced in ADR-0021): Batch operations count successes and failures separately, ensuring the log distinguishes between "removed from 3 groups" (three succeeded) and "removed from 5 groups but 2 failed." Each failure is logged as a separate entry so the CSV is the complete source of truth.
- **Best-effort name resolution with GUID fallback**: When fetching related objects (groups, roles), the script attempts to resolve human-readable names but falls back to GUIDs if resolution fails, ensuring the audit entry is always unambiguous.
- **Conditional status reporting**: Log entries use status codes ("OK", "SKIPPED", "FAILED") with color-coded console output; the Notes field captures counts, error details, or operator input (e.g., whether an out-of-office message was set).
- **Scope-limited connection**: Graph connections use `-ContextScope Process` to avoid polluting the user's persistent PowerShell profile.

### Change Log
- 2026-05-11: Release 1.1.0: V2 mailflow, expanded RequiredModules, audit-log integrity
- 2026-05-08: Fix script portability and password handling (#3)
- 2026-05-07: Fix Publish.ps1 string interpolation on GUID error message
- 2026-05-07: Initial Release