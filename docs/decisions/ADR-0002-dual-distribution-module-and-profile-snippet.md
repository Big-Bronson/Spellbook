# ADR-0002: Dual distribution — Gallery module and standalone profile snippet

**Date:** 2026-05-07  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

The invoke targets MSP engineers who may be in different situations: some have admin rights to install modules from the Gallery, some work on shared/managed machines where `Install-Module` is unavailable or slow, and some may want to try the tool with zero installation. A second distribution path was provided from the initial release in the form of `invoke-profile.ps1`.

---

## Decision

The project ships two parallel forms of the same dispatcher:

1. **`Spellbook` module** (PowerShell Gallery, `Install.ps1`) — the full package with `Public/*.ps1` dot-sourced from `Spellbook.psm1`. Recommended for regular use.
2. **`invoke-profile.ps1`** — a single-file profile snippet containing the `invoke()` dispatcher with hardcoded `$scriptsPath`. The engineer pastes this into their `$PROFILE` and drops the individual `.ps1` files into a `$env:USERPROFILE\Scripts` folder. No module installation required.

`invoke-profile.ps1` is explicitly not part of the Gallery package and is not dot-sourced by the module.

---

## Rationale

[inferred] The profile snippet predates the module. The original `invoke()` function was likely a profile snippet before the project was packaged as a module. Keeping it maintained alongside the module supports engineers who cannot or will not use the Gallery.

The two distribution paths share the same command names, section structure, and invocation syntax (`invoke <command>`), so knowledge is transferable regardless of which path an engineer uses.

---

## Alternatives considered

**Module only** — Simpler to maintain, but excludes engineers on managed machines or those who prefer not to add dependencies to their profile.

**Profile snippet only** — No module, no Gallery. Simpler, but loses discoverability (you can't `Find-Module Spellbook`), version management, and automatic dependency installation.

---

## Consequences

- **Maintenance overhead:** Every new command must be added to both `Spellbook.psm1` ($commands hashtable) and `invoke-profile.ps1` ($commands hashtable). These can drift if not kept in sync. There is no automated check for this drift.
- `invoke-profile.ps1` runs scripts via the call operator (`& $scriptFile`) while the module uses dot-sourcing (`.$scriptFile`). Variable scope and session continuity differ slightly between the two paths — this is an accepted inconsistency.
- `invoke-profile.ps1` contains commands (`rename-pc`, `get-licensedusers`) that do not exist as shipped `Public/*.ps1` files. These are planned/aspirational entries in the profile snippet that have not been implemented in the module.

---

## Related files

- `invoke-profile.ps1` — the standalone snippet
- `Spellbook.psm1` — the module dispatcher
- `Install.ps1` — installs the module version; does not touch `invoke-profile.ps1`
