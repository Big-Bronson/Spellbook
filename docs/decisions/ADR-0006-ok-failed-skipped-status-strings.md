# ADR-0006: `[OK]` / `[FAILED]` / `[SKIPPED]` as the standard step-status vocabulary

**Date:** 2026-05-07  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

`offboard-user.ps1` performs 11 sequential steps and needs to display progress and log the result of each one. The status of each step needs to be human-readable in the terminal and machine-readable in the CSV export (for filtering, ticket attachment, audits). A consistent vocabulary across all multi-step commands makes terminal output and log files predictable.

---

## Decision

All multi-step commands and bulk-operation loops use exactly three status strings: **`OK`**, **`FAILED`**, and **`SKIPPED`**. These are printed in brackets (`[OK]`, `[FAILED]`, `[SKIPPED]`) in terminal output and written verbatim to the `Status` column of CSV log files.

Colour mapping is consistent across all scripts:
- `OK` → `Green`
- `SKIPPED` → `DarkGray`
- `FAILED` → `Red`

---

## Rationale

Three states cover all cases: the step ran and succeeded, the step ran and failed, or the step was intentionally not run (pre-condition already met, or user declined an optional step). No fourth state is needed for this tool's use cases.

Using fixed strings rather than free-form text in the `Status` column makes the CSV filterable — an engineer or an automated ticket parser can `Where-Object { $_.Status -eq "FAILED" }` to extract only the steps that need follow-up.

Consistent colour mapping means engineers reading terminal output do not need to think about what colour means what.

---

## Alternatives considered

**Free-form status strings** — More descriptive per-step but not filterable. A log with "Password reset failed — Graph timeout" in the Status column cannot be filtered the same way as one with "FAILED". Notes column handles the free-form detail.

**Boolean `Success` column** — Loses the `SKIPPED` distinction, which is meaningful (SKIPPED is not a failure). Ruled out.

**Numeric status codes** — Machine-readable but not human-readable in a terminal or when attached to a support ticket. Ruled out.

---

## Consequences

- Any new multi-step command or bulk-operation loop must use these three strings and the corresponding colours.
- The `Notes` column in log objects carries the free-form detail (error message, count, reason for skip) that the `Status` field cannot.
- The `Log-Action` helper function in `offboard-user.ps1` encapsulates this pattern; other scripts that implement similar per-step logging should copy or extract that function rather than reinventing it.

---

## Related files

- `Public/offboard-user.ps1` — defines `Log-Action`; the reference implementation
- `Public/disable-autocalevents.ps1` — per-mailbox loop using the same status strings inline
