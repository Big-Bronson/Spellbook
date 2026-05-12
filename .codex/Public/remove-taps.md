## Public/remove-taps.ps1

### What This File Does
This script identifies all active Temporary Access Pass (TAP) authentication methods assigned to a specified user in Microsoft Entra ID, displays their creation and expiry details, and removes them upon confirmation. It operates as an interactive operator tool that connects to Microsoft Graph, queries the target user's TAP inventory, and deletes selected credentials.

### Why It Exists
Temporary Access Passes are time-limited authentication credentials used for emergency access or onboarding scenarios. While TAPs expire naturally, situations like phishing incidents or policy violations require immediate credential revocation rather than waiting for expiry. This script provides operators a direct way to instantly invalidate all TAPs for a user without waiting for natural expiration or manual Microsoft Entra ID portal navigation.

### What It Protects Against
The script guards against silent failures in bulk TAP deletion by:
- Catching and reporting individual removal failures without stopping the entire operation
- Confirming user identity before deletion (prevents typos in UPN)
- Displaying expiry information before confirmation (prevents accidental removal of valid TAPs)
- Tracking and reporting the count of successful vs. attempted removals

It does not protect against unauthorized operator access or permission escalation—that is delegated to Microsoft Graph scoping.

### Invariants
- The operator must be authenticated to Microsoft Graph with `UserAuthenticationMethod.ReadWrite.All` scope before execution
- The user identified by UPN must exist in the connected tenant
- Each TAP object returned by Graph must have `Id`, `CreatedDateTime`, `StartDateTime`, `LifetimeInMinutes`, and `IsUsableOnce` properties
- The confirmation prompt must be explicitly answered with "y" to proceed with deletion

### Key Patterns
**Defensive Graph connection**: The script checks for an existing Graph context and auto-connects with required scopes if missing, eliminating a common pre-flight failure.

**User lookup before action**: UPN is used to fetch the user object and confirm existence, catching typos early and avoiding cryptic downstream errors.

**Display-then-confirm**: TAP details (creation time, expiry, one-time flag) are shown before the destructive confirmation prompt, allowing operators to verify they're deleting the right credentials.

**Partial success tracking**: The script counts successful removals separately and reports both, allowing operators to detect partially failed operations requiring retry.

### Change Log
- 2026-05-08: Initial commit introducing remove-taps as part of MFA family tooling to enable immediate TAP revocation beyond natural expiry.