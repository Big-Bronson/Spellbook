# ADR-0008: `RequiredModules` pins minimum versions, not exact versions

**Date:** 2026-05-07  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

`StevesScriptorium.psd1` declares three `RequiredModules` entries with `ModuleVersion` constraints:

```powershell
RequiredModules = @(
    @{ ModuleName = 'ExchangeOnlineManagement'; ModuleVersion = '3.0.0' }
    @{ ModuleName = 'Microsoft.Graph.Users';    ModuleVersion = '2.0.0' }
    @{ ModuleName = 'Microsoft.Graph.Identity.SignIns'; ModuleVersion = '2.0.0' }
)
```

In PowerShell module manifests, `ModuleVersion` in a `RequiredModules` entry means **minimum version**, not exact version. The module will load if the installed version is `≥` the declared version.

The three other Microsoft.Graph sub-modules (`Microsoft.Graph.Authentication`, `Microsoft.Graph.Groups`, `Microsoft.Graph.Reports`) are listed in `Install.ps1` for installation but are **not** in `RequiredModules` because they are dependencies of the declared Graph modules and are installed transitively.

---

## Decision

**Minimum-version pinning only.** Exact versions are not pinned. Floors are set at the major version boundaries where breaking changes occurred (EXO v3, Graph v2) to guard against engineers running very old versions.

---

## Rationale

**Flexibility for engineers on managed machines:** MSP engineers often work on machines where IT has already installed a newer version of `ExchangeOnlineManagement` or the Graph SDK. Exact-version pinning would cause side-by-side installation of an older version, or would refuse to load if the exact version is not present. Minimum-version pinning lets the module use whatever compatible version is already installed.

**Module update propagation:** Microsoft releases updates to both `ExchangeOnlineManagement` and the Graph SDK frequently. Exact pinning would require a module release every time a dependency updates, even if nothing changed in `StevesScriptorium` itself. Minimum pinning lets dependency updates flow in without forcing a patch release.

**Major-version floors:** EXO v3 introduced the modern REST-based cmdlets (v2 used RPS). Graph v2 changed authentication and property handling significantly. Floors at these boundaries prevent the module from loading against versions that are genuinely incompatible.

---

## Alternatives considered

**Exact version pinning (`RequiredVersion`)** — Prevents breakage from unexpected upstream changes but causes side-by-side installation sprawl and requires a `StevesScriptorium` release for every dependency patch. Too rigid for a fast-moving ecosystem.

**No version constraint at all** — Would allow loading against EXO v1 or Graph v1, which have different cmdlet names and behaviours. Some scripts would fail silently with confusing errors. Minimum floors are necessary.

**Pin all six Graph sub-modules explicitly** — Would be more explicit but `Microsoft.Graph.Authentication` etc. are transitive — they are installed automatically when the declared modules install. Declaring them in `RequiredModules` adds no protection and bloats the manifest.

---

## Consequences

- If Microsoft releases a Graph v3 or EXO v4 with breaking changes, the minimum floor will not protect against it. Engineers will encounter failures at runtime, not at module load time. This is an accepted risk.
- The `Install.ps1` module list and `RequiredModules` are slightly out of sync (Install.ps1 installs 6 modules; psd1 declares 3). This is intentional — the 3 psd1 entries are the load-time requirements; the additional 3 in Install.ps1 are convenience installations.

---

## Related files

- `StevesScriptorium.psd1` — `RequiredModules` block
- `Install.ps1` — the fuller list of modules installed at setup time
