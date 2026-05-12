## Public/set-smsmfa.ps1

### What This File Does
This script updates the phone number on an existing SMS/phone-based MFA method for an Azure AD user. It connects to Microsoft Graph, prompts an operator to select a user and one of their registered phone methods, then replaces that method's phone number with a new one provided in E.164 format.

### Why It Exists
Users need their MFA phone numbers updated when they change devices, carriers, or phone numbers. Rather than deleting and re-registering methods (which may disrupt MFA temporarily), this script allows in-place updates while preserving the method type (mobile, alternate mobile, office) and the method's identity in the authentication system.

### What It Protects Against
- **Missing Graph connection**: Establishes Graph context automatically if not already authenticated, preventing silent failures due to missing credentials.
- **Invalid user input**: Validates that the UPN exists in Azure AD and that the menu selection is numeric and within bounds.
- **Empty phone list**: Detects when a user has no registered phone methods and directs the operator to `add-smsmfa` instead of attempting an update.
- **Incomplete input**: Aborts if the operator provides an empty phone number rather than attempting an update with null data.
- **Graph API errors**: Catches and reports update failures with the underlying error message.

### Invariants
- The operator must be authenticated to Microsoft Graph with `UserAuthenticationMethod.ReadWrite.All` scope before or during execution.
- The target user must exist in Azure AD and be queryable by UPN.
- The target user must have at least one registered phone authentication method.
- The new phone number must be a valid string; validation of E.164 format is deferred to the Graph API.
- The method ID retrieved from the first query must still be valid at the time of the update (concurrent deletion would cause failure).

### Key Patterns
- **Interactive menu**: Lists available methods with 1-based indexing and prompts operator selection, reducing the risk of updating the wrong method.
- **Defensive Graph queries**: Uses `-ErrorAction SilentlyContinue` on read operations and converts results to arrays (`@(...)`) to handle zero or multiple results consistently.
- **Confirmation via re-entry**: Requires the operator to explicitly provide the new phone number rather than defaulting or auto-detecting, ensuring intentional changes.
- **Preserve-on-update**: Re-submits the existing `PhoneType` to the Graph API during the update, ensuring the method classification is not accidentally cleared.

### Change Log
- 2026-05-08: Initial addition as part of MFA family feature set.