# ADR-0017: Portable CSPRNG password generator instead of `System.Web.Security.Membership`

**Date:** 2026-05-08  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

`offboard-user.ps1` needs to reset the departing user's password to a random string that the engineer can record in the audit log. The 1.0.0 implementation used `[System.Web.Security.Membership]::GeneratePassword()`, which is part of `System.Web` — a .NET Framework assembly that is not available on PowerShell 7 / .NET Core. Engineers running PS 7 (which is the recommended shell per the module's own documentation) would see an error at the password-reset step during offboarding.

Fixed in commit 33f89e2 (2026-05-08).

---

## Decision

`offboard-user.ps1` uses a **portable generator built on `System.Security.Cryptography.RandomNumberGenerator`**, available in both .NET Framework (PS 5.1) and .NET (PS 7+). The generator:

1. Guarantees at least one character from each of four classes (uppercase, lowercase, digit, symbol) to satisfy M365 complexity requirements.
2. Fills the remaining length from the combined pool.
3. Shuffles the result in-place using Fisher-Yates driven by the same CSPRNG, preventing the guaranteed characters from always appearing in the same positions.

The function is defined inline in `offboard-user.ps1` as `New-OffboardPassword`.

---

## Rationale

**`System.Security.Cryptography.RandomNumberGenerator`** is part of `System.Security.Cryptography`, which ships with every supported .NET runtime. It provides cryptographic-quality randomness, which is appropriate for a password that will be written to an audit log and potentially communicated to a manager or ticketing system.

**Guaranteed complexity classes:** M365's password policy rejects passwords that do not contain at least one character from each required class. Seeding randomly without guarantees would produce valid-looking passwords that occasionally fail the API call. Guaranteeing one of each class and then filling randomly avoids this.

**Fisher-Yates shuffle driven by CSPRNG:** Without the shuffle, the four guaranteed characters always appear at positions 0-3, which is detectable bias. Shuffling eliminates this.

**Inline definition:** The function is defined inside `offboard-user.ps1` rather than in `Private/`, because it is the only script that needs it. Following the project's principle of self-contained scripts (ADR-0003), inlining is correct.

---

## Alternatives considered

**`[System.Web.Security.Membership]::GeneratePassword()`** — The original implementation. Unavailable on PS 7 / .NET Core. Eliminated.

**`Get-Random`** — PowerShell's `Get-Random` is not cryptographically secure (it wraps `System.Random`, which is a pseudo-RNG). Not appropriate for a password that will be logged and potentially transmitted.

**Third-party module** — Would add a dependency for a single function. The module already minimises dependencies; adding one for password generation is not justified.

---

## Consequences

- `offboard-user.ps1` works correctly on both PS 5.1 and PS 7+.
- The generated password (20 characters, mixed classes) is recorded in the `Notes` column of the CSV log for the audit trail.
- The generator does not produce ambiguous characters (e.g. `0`/`O`, `1`/`l`) by design — the character pool in the function deliberately excludes them.
- If a future script also needs random password generation, the function should be moved to `Private/` and shared, or a `New-SecurePassword.ps1` helper added.

---

## Related files

- `Public/offboard-user.ps1` — `New-OffboardPassword` function defined and called inline
- `CLAUDE.md` — documents the PS 7 portability constraint and points to this pattern
