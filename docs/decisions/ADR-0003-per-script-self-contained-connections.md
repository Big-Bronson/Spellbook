# ADR-0003: Each public script connects its own Graph and Exchange sessions

**Date:** 2026-05-07  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

Commands need Microsoft Graph and/or Exchange Online connections to function. There are two broad approaches: a centralised connection managed at module level (connect once, reuse everywhere), or per-script connections where each script checks and establishes its own connection. Because scripts run via dot-sourcing (ADR-0001), the session persists — either pattern can work technically.

The module serves multiple MSP engineers who may be connecting to different tenants in different sessions, or running just a single command without importing the full module.

---

## Decision

Each `Public/*.ps1` script that needs Graph or Exchange **checks for an existing connection and establishes one if absent**, at the top of the script. The pattern is:

```powershell
if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline -ShowBanner:$false }
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.Read.All","..." -ContextScope Process
}
```

Each script requests **only the scopes it needs**, not a superset. There is no global connection step.

Graph connections use `-ContextScope Process` to avoid polluting a broader session context.

---

## Rationale

**Minimum-privilege scopes:** A script that only reads user data should not hold `Directory.ReadWrite.All`. If an engineer runs `get-userreport` and then `offboard-user`, each command negotiates only what it requires. This limits blast radius from a mistaken connection.

**Independent runnability:** Scripts can be run directly (e.g. `.\Public\get-userreport.ps1`) or via `toolkit` without needing a module-level setup step. This supports the profile-snippet distribution path (see `toolkit-profile.ps1`) and makes individual scripts usable outside the module.

**Re-use when already connected:** The `if (-not ...)` guard means that if an engineer has already authenticated (e.g. from the previous command), the check is near-zero cost — it does not re-prompt or re-auth.

**Tenant switching:** Engineers working across multiple tenants in one session can `Disconnect-MgGraph` / `Disconnect-ExchangeOnline` between commands without the module getting confused about which tenant it's connected to.

---

## Alternatives considered

**Module-level `Connect-*` in the psm1** — Would force auth at import time, not command time. Adds friction when importing the module for non-tenant use (e.g. `kill-graph`). Breaks independent script runnability.

**Shared connection helper in `Private/`** — A private function that all scripts call. Would centralise the guard logic but not reduce scope footprint — scripts would still need to declare their scopes. More abstraction for little gain.

---

## Consequences

- An engineer who runs 5 commands in a session will be prompted to authenticate at most twice (once for Graph, once for Exchange) if no connection exists. In practice, re-auth is rare since sessions persist.
- Each script must declare its own scope list. This is slightly repetitive but explicit and auditable — the README permissions table is populated from reading these declarations.
- If Graph or Exchange releases a breaking change to the connection API, every script needs updating. Accepted as a reasonable cost for the independence benefit.

---

## Related files

- All `Public/*.ps1` — each implements the connection guard pattern
- `README.md` — permissions table summarising scopes per command
