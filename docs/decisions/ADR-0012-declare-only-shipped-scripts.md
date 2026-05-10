# ADR-0012: `FunctionsToExport` declares only scripts that actually ship

**Date:** 2026-05-08  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

The 1.0.0 manifest declared 30 entries in `FunctionsToExport` — the full intended command surface including all planned commands. Only 13 of those had matching scripts in `Public/`. This caused two concrete failures:

1. The Publish.ps1 sync-check (added in the 1.0.1 cycle) immediately aborted because declared functions had no matching scripts.
2. Users who ran `toolkit 18` (for example) got a "Script not found" error — the command was listed in the menu but had no implementation.

The 1.0.1 release trimmed `FunctionsToExport` to the 13 scripts that existed, removed the 17 phantom entries from the toolkit menu, and moved all unimplemented commands to a "Planned" section in `README.md`.

---

## Decision

`FunctionsToExport` in `StevesScriptorium.psd1` contains **only the names of scripts that currently exist in `Public/`**, plus `toolkit` (which is defined in the psm1, not as a script). When a new command is implemented, it is added to `FunctionsToExport` in the same commit that adds the script. Planned-but-unimplemented commands live only in the README.

The Publish.ps1 sync-check and the Pester `FunctionsToExport vs Public/` tests both enforce this mechanically.

---

## Rationale

Declaring phantom functions causes visible failures for users (broken menu entries, misleading `Find-Module` function lists on the Gallery). The Gallery's module page lists all `FunctionsToExport` entries — users see them as promises of functionality. A function that is listed but produces "Script not found" when called is a broken promise.

The "Planned" README section serves the same communication purpose — users can see what is coming — without making a promise that is encoded in a published artifact.

---

## Alternatives considered

**Keep ghost entries but hide them from the menu** — The Gallery listing would still show them, misleading users. Ruled out.

**Use a separate `PlannedFunctions` key in PrivateData** — Not a standard manifest field; Gallery tooling would not use it. The README is the right place for forward-looking information.

---

## Consequences

- The sync-check in Publish.ps1 and the Pester tests provide a hard enforcement mechanism — it is impossible to accidentally publish a ghost function if the checks pass.
- When implementing a planned command, the contributor must add it to `FunctionsToExport`, the `$commands` hashtable in `StevesScriptorium.psm1`, the README command table, and remove it from the README "Planned" list. The CLAUDE.md "How to add a new command" checklist captures this.
- The README "Planned" section may drift from what is actually planned — it is a best-effort list, not a contract.

---

## Related files

- `StevesScriptorium.psd1` — `FunctionsToExport`
- `Publish.ps1` — sync-check step 3
- `tests/Module.Tests.ps1` — `FunctionsToExport vs Public/` describe block
- `README.md` — "Planned" section
