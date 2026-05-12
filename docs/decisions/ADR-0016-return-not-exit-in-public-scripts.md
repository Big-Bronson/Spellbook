# ADR-0016: Public scripts use `return`, never `exit`, for early termination

**Date:** 2026-05-08  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

Several `Public/*.ps1` scripts need early exit paths — e.g. when a user is not found, a confirmation prompt is declined, or a required parameter is missing. The initial release (1.0.0) used `exit` at these sites. After shipping, it was discovered that `exit` inside a dot-sourced script terminates the entire PowerShell host, not just the script. An engineer running `invoke get-userreport` and getting a "user not found" result would find their terminal session killed.

Affected scripts in 1.0.0: `get-guestaudit`, `get-groupmembers`, `get-userreport`, `set-userlicence`, `offboard-user`. Fixed in commit 33f89e2 (2026-05-08).

---

## Decision

All `Public/*.ps1` scripts use **`return`** for all early exit paths. `exit` is never used in public scripts.

This rule is documented in `CLAUDE.md` as a known gotcha so future Claude Code sessions and contributors do not re-introduce the bug.

---

## Rationale

`return` from a dot-sourced script returns to the calling scope (i.e. `invoke()` or the prompt) without affecting the session. This is the correct behaviour for an interactive tool where early exit from one command should leave the engineer in the same terminal they started in.

`exit` inside a dot-sourced script calls `[Environment]::Exit()`, which terminates the PowerShell host process entirely.

---

## Alternatives considered

**Run commands in a child job (`Start-Job`) to contain `exit`** — Would isolate the exit but break interactive prompts (`Read-Host` cannot run in a background job) and destroy session continuity. Incompatible with ADR-0001.

**Wrapper try/catch around the dot-source call in `invoke()`** — `exit` is not a PowerShell exception; it cannot be caught with try/catch. Would not work.

**Linter rule** — PSScriptAnalyzer does not have a built-in rule for detecting `exit` in dot-sourceable scripts. Could be a custom rule, but the simpler fix is just to use `return` correctly.

---

## Consequences

- Early exit from any command returns control to the caller cleanly.
- Scripts cannot signal a non-zero exit code to external callers (e.g. CI). This is acceptable because these scripts are designed for interactive use, not pipeline orchestration.
- Contributors must remember this rule when writing new scripts. It is documented in `CLAUDE.md` under "Known gotchas".

---

## Related files

- `CLAUDE.md` — documents this gotcha explicitly
- `Public/get-guestaudit.ps1`, `Public/get-groupmembers.ps1`, `Public/get-userreport.ps1`, `Public/set-userlicence.ps1`, `Public/offboard-user.ps1` — the files that were patched
