# ADR-0001: Dot-source dispatch — commands run in the caller's session

**Date:** 2026-05-07  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

The invoke needs a CLI dispatcher that can run any of 20+ commands by name or number. Commands need access to variables and connection state established in the same session. The audience is MSP engineers who work interactively in a terminal — speed of feedback and seamless session continuation matter more than isolation.

---

## Decision

`invoke()` dispatches commands by **dot-sourcing** (`.$scriptPath`) the target `Public/*.ps1` file inside the caller's PowerShell session, not by invoking it as a subprocess or child scope.

The psm1 also dot-sources all `Public/*.ps1` at module load time to register each file as a named global function, so commands can also be called directly by name (e.g. `get-userreport`) without going through `invoke`.

---

## Rationale

Dot-sourcing means the command runs in the same scope as the operator:

- Graph and Exchange connections established before a command remain usable during it, and the command's connections persist for the next command — no re-auth per call.
- Output, errors, and variables stay in the same terminal window without cross-process serialisation.
- Interactive prompts (`Read-Host`) work naturally.

For a helpdesk tool where an engineer runs 3-4 commands per support call, session continuity is a first-order requirement.

---

## Alternatives considered

**Invoke-Expression / & (call operator) in a child scope** — Commands would be isolated per call, but Graph/Exchange connections would not persist between commands, forcing re-auth every time. Ruled out.

**Compiled cmdlets (C# binary module)** — Too heavy for a team maintaining scripts in plain text. The point of this project is that engineers can read and modify commands in Notepad if needed.

**Wrapper functions with param blocks** — Each command is a self-contained interactive script that prompts for all inputs; a formal param block would require the caller to know the parameters upfront. The interactive prompt-per-step pattern is intentional.

---

## Consequences

- **The critical consequence:** because scripts run in the caller's scope, `exit` terminates the user's PowerShell session, not just the script. All `Public/*.ps1` scripts must use `return` for early exits. (See ADR-0002.)
- Variables defined inside a script may leak into the caller's scope after the command returns. Mitigated by not naming script variables in ways that collide with common session variables.
- Adding a command is as simple as dropping a `.ps1` in `Public/` and updating `FunctionsToExport` — no registration step needed.

---

## Related files

- `Spellbook.psm1` — dot-sources all `Public/*.ps1` at load time; `invoke()` dispatches via dot-source at runtime
- `Public/*.ps1` — every command script
