# ADR-0011: Publish.ps1 enforces a pre-flight gate before every Gallery publish

**Date:** 2026-05-08  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

The 1.0.0 `Publish.ps1` was a thin wrapper around `Publish-Module` that read an API key from a config file and published immediately. After the 1.0.0 release, the manifest was discovered to declare 30 functions of which 17 had no matching script — ghost exports caused by declaring planned commands before implementing them. The broken manifest was on the Gallery for real users. `Publish.ps1` was rewritten in commit 2b64710 (2026-05-08).

---

## Decision

`Publish.ps1` runs **five pre-flight checks** before touching the Gallery, and aborts on any failure:

1. **Manifest validation** — `Test-ModuleManifest` must succeed.
2. **Parse-check** — Every `Public/*.ps1` is parsed with `[System.Management.Automation.Language.Parser]::ParseFile`; any syntax error aborts.
3. **Sync check** — `FunctionsToExport` in the manifest must match the actual files in `Public/` exactly (ghost exports fail; undeclared scripts fail).
4. **Clean git tree on `main`** — The working tree must be clean and the current branch must be `main`. Skippable via `-SkipGitCheck` for deliberate exceptions.
5. **CHANGELOG presence** — `[Unreleased]` must exist and contain non-empty content (not just empty section headers).

The API key is read from **Windows Credential Manager** via a `Get-StoredSecret` helper that the operator adds to their `$PROFILE`, with `$env:PSGALLERY_API_KEY` as a fallback for CI or one-off use. The key is never stored in the repo.

---

## Rationale

**Manifest sync check:** The class of bug that broke 1.0.0 (ghost exports) is mechanical — it can be detected automatically by comparing two lists. Making it a hard abort means this class of bug cannot reach the Gallery again.

**Parse check:** A broken script that doesn't parse will crash every user who calls it. Checking syntax costs under a second and eliminates this failure mode entirely.

**Clean tree requirement:** Publishing from a dirty tree means the published version may not match what is in version control, creating a reproducibility gap. The `-SkipGitCheck` escape hatch exists for deliberate release-branch workflows.

**CHANGELOG gate:** Forces the publisher to document what changed before shipping. The check is structural (non-empty content under `[Unreleased]`), not semantic — it cannot verify the notes are meaningful, but it prevents the accidental publish of an undocumented version.

**Credential Manager priority:** The API key should never be in the repo or in a dotfile. Credential Manager is the OS-provided secrets store on Windows; it is appropriate for a key that is used by a named individual. The env-var fallback supports CI pipelines that cannot use Credential Manager.

---

## Alternatives considered

**Publish without checks** — The 1.0.0 approach. Resulted in the broken manifest reaching the Gallery. Eliminated.

**Pester test gate (run Pester before publishing)** — Pester tests were added later (PR #10). Publish.ps1 runs its own checks independently so that publishing does not require Pester to be installed.

**GitHub Actions publish workflow** — Automated publishing on tag push. Not implemented because the publish decision is deliberate and human — an engineer should consciously trigger it. The pre-flight checks make the manual step safe enough.

---

## Consequences

- A publisher cannot accidentally push an inconsistent or undocumented version.
- The CHANGELOG gate has a known edge case: after cutting a release, `[Unreleased]` is intentionally empty. Publish.ps1 will refuse to publish again until a new bullet is added under `[Unreleased]`. This is a minor friction for the first post-release publish; documented as a known issue in the handoff notes.
- `Publish.ps1` must be run from the repo root (it uses relative paths for `.\Public`, `.\CHANGELOG.md`, etc.).

---

## Related files

- `Publish.ps1` — full implementation
- `StevesScriptorium.psd1` — the manifest validated and sync-checked by Publish.ps1
- `CHANGELOG.md` — the file whose `[Unreleased]` section must be populated
