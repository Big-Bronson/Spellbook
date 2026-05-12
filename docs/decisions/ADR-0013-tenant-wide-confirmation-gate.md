# ADR-0013: Tenant-wide destructive commands require typing the primary domain to confirm

**Date:** 2026-05-08  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

Some Spellbook commands make changes that affect every mailbox in the tenant — they are not reversible with a single undo, and running them against the wrong tenant (e.g. an engineer who is connected to a client tenant they did not intend) could cause widespread disruption. A simple `y/n` prompt is insufficient because it can be answered without the engineer consciously verifying which tenant they are operating against. `disable-autocalevents` was the first command in this category.

---

## Decision

Commands that make **tenant-wide changes** implement a **domain-confirmation gate**:

1. The script fetches the tenant's display name and primary verified domain from `Get-MgOrganization`.
2. It displays the tenant name and domain prominently.
3. It requires the operator to **type the exact primary domain string** (not just `y`) before proceeding.
4. A mismatch aborts with no changes made.

```powershell
$typed = Read-Host "Type the primary domain ($primaryDomain) to confirm"
if ($typed -ne $primaryDomain) {
    Write-Host "Confirmation failed. Aborted." -ForegroundColor Red
    return
}
```

---

## Rationale

Typing a domain name is a deliberate act that requires the engineer to read what is on screen and reproduce it. It is significantly harder to do accidentally than pressing `y`. MSP engineers manage multiple tenants in a single day; the additional friction on tenant-wide operations is proportionate to the risk.

The pattern is borrowed from cloud provider CLIs (e.g. `aws s3 rb --force` requiring explicit bucket name confirmation, Heroku `heroku apps:destroy --confirm <app-name>`).

---

## Alternatives considered

**`y/n` prompt** — Standard for per-user operations. Not sufficient for tenant-wide changes; an engineer could confirm without checking which tenant is active.

**`-Force` switch** — Would allow automation to bypass the gate. Since these commands are explicitly designed for interactive human use, automation bypass is not a goal. Ruled out.

**Double confirmation (`y/n` twice)** — Marginally better than once but still does not force the engineer to identify the tenant. Ruled out.

---

## Consequences

- Tenant-wide operations take a few extra seconds for the confirmation step. Accepted cost.
- The domain is fetched from `Get-MgOrganization`, which requires an `Organization.Read.All` Graph scope. Commands using this pattern must declare that scope even if they otherwise only use Exchange cmdlets.
- Future commands that modify tenant-wide settings (e.g. a hypothetical `enable-autoexpand` applied to all mailboxes) should use this same gate. It should be treated as a project convention, not a one-off.

---

## Related files

- `Public/disable-autocalevents.ps1` — first command to implement this pattern
