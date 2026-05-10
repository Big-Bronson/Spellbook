# ADR-0018: Operator-typed passwords are read as `SecureString` and never echoed

**Date:** 2026-05-08  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

`new-user.ps1` in the 1.0.0 release read the initial password via plain `Read-Host`, which echoes the typed characters to the terminal and records them in the session's command history and scrollback buffer. The password also appeared in the script's "Done" summary at the end. MSP engineers share screens during remote support sessions; a visible password is a security exposure.

Fixed in commit 33f89e2 (2026-05-08) as part of the script-portability pass.

---

## Decision

Any script that accepts a password typed by the operator uses **`Read-Host -AsSecureString`**. The `SecureString` is converted to a plain string only at the point where the API requires it, using:

```powershell
$plainPw = [System.Net.NetworkCredential]::new('', $securePw).Password
```

The plain-text variable is cleared immediately after use in a `finally` block:

```powershell
try {
    New-MgUser ... -PasswordProfile @{ Password = $plainPw; ... }
} finally {
    $plainPw = $null
}
```

The script's completion summary prints `(set — not echoed)` rather than the password value.

Scripts that **generate** a password (like `offboard-user`) are exempt — the generated password must appear in the audit log by design, and there is no operator-typed secret to protect.

---

## Rationale

`Read-Host -AsSecureString` masks input and does not leave the typed value in the terminal scrollback. The `[System.Net.NetworkCredential]` conversion is the idiomatic PowerShell 5.1-compatible way to extract the plain string from a `SecureString` without using `Marshal` (which requires `unsafe` context) or `BSTR` (Windows-only, unreliable in PS7). The `finally` block ensures the plain string is nulled even if `New-MgUser` throws.

The conversion happens at the call site, not at the point of reading, to minimise the time the plain string exists in memory.

---

## Alternatives considered

**`Read-Host` (plain)** — The 1.0.0 approach. Leaves the password in scrollback and terminal history. Eliminated.

**`Get-Credential`** — Produces a `PSCredential` object and shows a GUI dialog, which is disruptive in a CLI tool and behaves differently across PS 5.1 and PS 7 on Windows vs non-Windows. Ruled out.

**`ConvertFrom-SecureString` / `Marshal.PtrToStringAuto`** — Platform-specific (`Marshal` approach only works on Windows). `[System.Net.NetworkCredential]` works cross-platform. Preferred.

---

## Consequences

- Operator-typed passwords are not visible in the terminal or PowerShell session history.
- The plain string exists in memory only for the duration of the API call. PowerShell's GC does not guarantee immediate collection of `$null`-ed strings, but this is the best achievable without native SecureString support in the Graph SDK.
- Scripts that accept passwords must follow this pattern. The rule applies to any future command that reads a password interactively — e.g. `reset-password` if it supports an operator-supplied password.

---

## Related files

- `Public/new-user.ps1` — the reference implementation of this pattern
