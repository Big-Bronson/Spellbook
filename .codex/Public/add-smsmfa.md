## Public/add-smsmfa.ps1

### What This File Does
This script adds a new phone-based MFA method to a user's Azure AD authentication profile. It prompts an operator to supply a UPN and phone number, lets them choose among three phone types (mobile, alternate mobile, or office), then registers that phone number with Microsoft Graph so the user can receive SMS or voice-call MFA codes.

### Why It Exists
Organizations need a way to enroll users in SMS/phone-based MFA without requiring users to self-register or waiting for them to adopt authenticator apps. This script lets support or identity teams quickly add phone MFA methods to user accounts during onboarding or when users have lost access to other MFA devices.

### What It Protects Against
The script defends against four concrete failure modes: (1) running without an active Microsoft Graph connection by auto-connecting if needed, (2) typos in the UPN by validating the user exists before proceeding, (3) malformed phone numbers by explicitly asking for E.164 format in the prompt, and (4) silent API failures by wrapping the registration call in a try-catch block and surfacing errors to the operator. It does *not* protect against invalid phone numbers that pass syntax validation but don't exist.

### Invariants
- A valid Microsoft Graph context must exist (with `UserAuthenticationMethod.ReadWrite.All` scope) before calling `New-MgUserAuthenticationPhoneMethod`
- The UPN supplied by the operator must match an actual user in the directory
- The phone number must be non-empty (the script returns early if blank)
- The phone type parameter must be one of: `"mobile"`, `"alternateMobile"`, or `"office"`

### Key Patterns
**Interactive prompting**: The script uses `Read-Host` to collect input rather than accepting pipeline parameters, treating this as a manual, attended operation rather than an automatable batch process. **Default fallback**: The type selector uses a switch with `default` to handle invalid choices gracefully (defaulting to mobile). **Inline validation**: User existence is checked immediately after lookup; the script returns early rather than proceeding with a null user object.

### Change Log
- 2026-05-08: Initial commit adding SMS MFA registration via `New-MgUserAuthenticationPhoneMethod` with mobile/alternate/office type selection