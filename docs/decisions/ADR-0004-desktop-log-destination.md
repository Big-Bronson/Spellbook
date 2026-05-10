# ADR-0004: CSV audit logs are written to the operator's Desktop

**Date:** 2026-05-07  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

Several commands produce audit logs or exports: `offboard-user` produces a per-offboarding CSV, `get-sharedmailboxaudit` and `get-guestaudit` produce tenant-wide reports, `disable-autocalevents` logs every mailbox it touched. These files need to land somewhere the engineer can find immediately after the command completes without navigating a directory tree.

---

## Decision

All CSV exports are written to **`$env:USERPROFILE\Desktop`** with a descriptive timestamped filename (e.g. `Offboard_jsmith_20260508_1430.csv`, `SharedMailboxAudit_20260508.csv`).

---

## Rationale

MSP engineers at a helpdesk typically attach offboarding logs or audit reports to the relevant support ticket immediately after running a command. The Desktop is the fastest point of access — it is visible in the taskbar, accessible from most file-open dialogs, and requires no navigation. This is a deliberate UX optimisation for the target user's actual workflow.

[inferred] The pattern was adopted from existing internal scripts used before this module was created; the Desktop convention predates this codebase.

---

## Alternatives considered

**Current working directory** — Works for engineers running from the repo root, but they are usually running from their profile and the CWD is unpredictable. Files would get lost.

**A module-managed log directory (e.g. `~/.scriptorium/logs/`)** — Organised but not immediately accessible. Adds a step between "command completes" and "file is in front of me". No benefit over Desktop for a single-file output per run.

**Returning the data as objects and letting the caller decide** — Philosophically clean but incompatible with the interactive-script model. Commands prompt for input mid-run; they cannot be piped into downstream commands in the traditional PowerShell pipeline sense.

---

## Consequences

- Engineers who run commands in an unattended or automated context (unlikely for this tool) will produce files on the Desktop of the account running the process.
- Log files accumulate on the Desktop over time; there is no cleanup mechanism. Engineers are expected to archive or delete them as part of their ticket workflow.
- The Desktop path is correct on both PS 5.1 and PS 7, and on Windows versions back to Windows 7, because `$env:USERPROFILE\Desktop` is reliable (unlike `[Environment]::GetFolderPath("Desktop")`, which may redirect to OneDrive on some systems).

---

## Related files

- `Public/offboard-user.ps1` — Desktop log: `Offboard_<username>_<timestamp>.csv`
- `Public/get-sharedmailboxaudit.ps1` — `SharedMailboxAudit_<date>.csv`
- `Public/get-guestaudit.ps1` — `GuestAudit_<date>.csv`
- `Public/disable-autocalevents.ps1` — `AutoCalEvents_<domain>_<timestamp>.csv`
