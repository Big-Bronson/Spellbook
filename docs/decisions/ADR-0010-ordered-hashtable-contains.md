# ADR-0010: `[ordered]@{}` for the command menu; `.Contains()` not `.ContainsKey()`

**Date:** 2026-05-08  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

The `invoke()` dispatcher prints a numbered list of commands and resolves numeric shortcuts (e.g. `invoke 3`). This requires the command registry to maintain **insertion order** so the numbers are stable and predictable. A standard PowerShell `@{}` hashtable does not guarantee key ordering. Additionally, after choosing `[ordered]@{}`, the initial implementation used `.ContainsKey()` to test whether a command name was in the registry — which threw `InvalidOperation` at runtime because `[ordered]@{}` creates a `System.Collections.Specialized.OrderedDictionary`, not a `System.Collections.Hashtable`, and `OrderedDictionary` does not have a `.ContainsKey()` method.

This bug caused every named command invocation (e.g. `invoke new-user`) to crash. Fixed in commit 2b64710 (2026-05-08).

---

## Decision

The `$commands` registry in `invoke()` is declared as `[ordered]@{}`. All presence checks use `.Contains()`, which is the correct method on `OrderedDictionary`.

This is documented in `CLAUDE.md` as the top known gotcha so future contributors (including Claude Code sessions) do not reintroduce `.ContainsKey()`.

---

## Rationale

`[ordered]@{}` is the idiomatic PowerShell way to get a dictionary with predictable iteration order. The numeric shortcut feature (`invoke 3`) depends entirely on stable order — the number corresponds to position in the list, not alphabetical sort or any other ordering.

`.Contains()` is the correct API. PowerShell's `Hashtable` has `.ContainsKey()` as a convenience, but `OrderedDictionary` does not inherit from `Hashtable` and only exposes `.Contains()`.

---

## Alternatives considered

**Regular `@{}` with a separate ordered key list** — Maintain a plain hashtable for lookups plus a `[string[]]` for order. More bookkeeping, no advantage. Ruled out.

**`[System.Collections.Generic.Dictionary[string,string]]`** — Generic dictionary; insertion-ordered in .NET 5+ (not guaranteed in .NET Framework / PS 5.1). Cross-version risk. Ruled out.

**`switch` statement or `if/elseif` chain** — No data structure at all; hard-code the dispatch. Works but makes adding commands tedious and precludes the dynamic numbered menu. Ruled out.

---

## Consequences

- The menu is stable: position 1 is always `new-user`, position 2 is always `offboard-user`, etc. Engineers can memorise numbers if they want to.
- **Any code that tests for key presence must use `.Contains()`**, never `.ContainsKey()`. Both `Spellbook.psm1` and `invoke-profile.ps1` had this patched; the rule applies to any future code that touches `$commands`.
- The `$sectionHeaders` hashtable in `invoke()` uses a plain `@{}` (regular hashtable), not `[ordered]`, because it is only used for lookup (not iteration), and that is fine.

---

## Related files

- `Spellbook.psm1` — `$commands` ordered hashtable; `.Contains()` call on line 105
- `invoke-profile.ps1` — parallel standalone implementation; same fix applied
- `CLAUDE.md` — documents this as a top-level gotcha
