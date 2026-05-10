# ADR-0007: `[System.Collections.Generic.List]` for in-script log accumulation

**Date:** 2026-05-07  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

Several scripts (`offboard-user`, `disable-autocalevents`, `get-tenantreport`) accumulate a list of log entries or findings during a loop — one entry per user or mailbox — and export the result as a CSV at the end. PowerShell's idiomatic approach is `$log += ...`, which appends to an array.

---

## Decision

Scripts that accumulate rows during a loop use **`[System.Collections.Generic.List[PSCustomObject]]::new()`** with `.Add()` rather than array concatenation (`+=`).

```powershell
$log = [System.Collections.Generic.List[PSCustomObject]]::new()
# inside loop:
$log.Add([PSCustomObject]@{ ... })
```

---

## Rationale

PowerShell arrays are fixed-size. `$log += $entry` creates a new array each time, copying all existing elements into it — O(n²) behaviour as the list grows. For a tenant with 500 users, a loop doing 500 array-concatenation operations allocates and copies ~125,000 objects total.

`[System.Collections.Generic.List[T]]` allocates a backing array and doubles it geometrically when capacity is exceeded — O(n) amortised for the full accumulation. For 500 users, the list reallocates ~9 times total.

MSP engineers manage tenants ranging from 20 to 2,000+ users. The performance difference is negligible at 20 users and meaningful at 2,000, where array-concat would add several seconds of pure allocation overhead to commands that already make hundreds of API calls.

---

## Alternatives considered

**`$log += ...` (array concatenation)** — Idiomatic PowerShell, familiar to anyone who knows the language. Correct but quadratic. Ruled out for loops that may iterate hundreds of times.

**`[System.Collections.ArrayList]`** — `.NET 1.1`-era non-generic list. Works, but `PSCustomObject` items are stored as `object` and trigger boxing. `Generic.List[PSCustomObject]` is the modern equivalent. Ruled out.

**Pre-allocating a fixed array** — `$log = [PSCustomObject[]]::new($count)` — Would require knowing the count before the loop. For API results paged from Graph, the count is often not known until iteration completes. Ruled out.

---

## Consequences

- Log accumulation performance is O(n) for all loop-based scripts.
- `Export-Csv` and `Format-Table` both accept `List[PSCustomObject]` directly; no conversion needed before export.
- The pattern is slightly more verbose than `+=` and unfamiliar to engineers who only know basic PowerShell. The first occurrence in each script should serve as a recognisable template.

---

## Related files

- `Public/offboard-user.ps1` — `$log = [System.Collections.Generic.List[PSCustomObject]]::new()`
- `Public/disable-autocalevents.ps1` — same pattern
- `Public/get-tenantreport.ps1` — uses `List[string]` for report lines and `List[PSCustomObject]` for flagged findings
