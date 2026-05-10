# ADR-0009: All `Get-MgUser` calls specify `-Property` explicitly

**Date:** 2026-05-07  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

The Microsoft Graph PowerShell SDK v2 changed the default behaviour of `Get-MgUser`: without `-Property`, the cmdlet returns only `Id` and `DisplayName`. Accessing any other property (e.g. `$user.AccountEnabled`, `$user.AssignedLicenses`) on a result returned without the corresponding `-Property` flag silently returns `$null` rather than raising an error. This is a common source of silent bugs — a script appears to work but produces empty or incorrect output because the data was never fetched.

---

## Decision

Every `Get-MgUser` call in `Public/*.ps1` specifies **`-Property`** with an explicit list of the properties the script actually reads. No call omits `-Property`.

```powershell
# Correct
$user = Get-MgUser -Filter "userPrincipalName eq '$upn'" `
    -Property "Id,DisplayName,AccountEnabled,AssignedLicenses,CreatedDateTime"

# Wrong — other properties will be $null
$user = Get-MgUser -Filter "userPrincipalName eq '$upn'"
```

The same principle applies to other `Get-Mg*` calls that support `-Property` (e.g. `Get-MgSubscribedSku`).

---

## Rationale

Explicit property selection serves two purposes:

1. **Correctness:** The SDK will not return a property that was not requested. Omitting `-Property` and then accessing `$user.AssignedLicenses` returns `$null` silently — the script appears to succeed but produces wrong results (e.g. all users look unlicensed).

2. **Performance:** Graph API responses include only the requested fields. Fetching all properties for 1,000 users in a tenant-wide report is significantly slower and consumes more memory than fetching 5 specific fields.

---

## Alternatives considered

**Omit `-Property` and rely on defaults** — The pre-v2 SDK behaviour returned more properties by default. v2 changed this. Any call without `-Property` is a latent bug waiting to surface when a new property is accessed. Ruled out.

**Use `-Select` (OData `$select`)** — This is the underlying Graph API parameter that `-Property` maps to. In the PS SDK, `-Property` is the correct parameter name. `-Select` does not exist on most `Get-Mg*` cmdlets. Not applicable.

**Fetch all properties with `-Property "*"`** — Works but defeats the performance benefit and fetches data the script does not need. Only appropriate when the full property set is genuinely unknown at write time.

---

## Consequences

- Adding a new property access to a script requires updating the `-Property` list in the same script. This is intentional friction that forces the developer to think about what data they need.
- Scripts are self-documenting about their data requirements — the `-Property` list is a readable declaration of what properties each command depends on.
- If Microsoft adds a new property to the Graph API that a script could benefit from, the property must be explicitly added to `-Property` — it will not appear automatically.

---

## Related files

- All `Public/*.ps1` files that call `Get-MgUser` — reference the `-Property` usage
- `Public/get-userreport.ps1` — most explicit example, fetching 10 properties
- `Public/get-allusers.ps1` — fetches 4 properties for a tenant-wide query (performance-critical)
