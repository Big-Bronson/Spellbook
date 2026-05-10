# ADR-0014: CI tests are static analysis only — no live tenant calls

**Date:** 2026-05-08  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

The `ci/pester-and-actions` PR added automated testing on every push and PR. A complete behavioural test suite would verify that `Get-MgUser`, `Set-Mailbox`, etc. produce the expected results — but those calls require a real M365 tenant, valid credentials, and reproducible test data. The GitHub Actions CI runner has none of these.

---

## Decision

`tests/Module.Tests.ps1` contains only **static checks** that do not require network access or credentials:

1. Manifest parses cleanly (`Test-ModuleManifest`)
2. `FunctionsToExport` in the manifest matches the actual files in `Public/` (no ghost exports, no undeclared scripts)
3. `toolkit` is explicitly declared in `FunctionsToExport`
4. `ProjectUri` and `LicenseUri` point at the correct repo slug
5. Every `Public/*.ps1` parses without syntax errors (AST parser)
6. `CHANGELOG.md` has an `[Unreleased]` section
7. `CHANGELOG.md` has a dated section matching the manifest version

These are the same checks that `Publish.ps1` runs — extracted into Pester so they run on every push, not just at publish time.

---

## Rationale

**The CI runner cannot authenticate to a real tenant.** Injecting service-principal credentials into GitHub Actions is possible but would require a dedicated test tenant, carefully scoped service principal, and ongoing maintenance of test data. The overhead is disproportionate for a small MSP tool.

**The manifest-sync and parse bugs that have actually shipped** (ghost exports in 1.0.0; `exit` in dot-sourced scripts) are detectable statically. The tests target the real failure modes seen in production.

**Running the same checks as Publish.ps1** means CI catches drift that would otherwise only surface at publish time — earlier feedback at zero extra cost.

---

## Alternatives considered

**Mock-based unit tests** — Would require mocking `Get-MgUser`, `Set-Mailbox`, etc. Mock drift from the real API has historically caused false-positive CI passes (this was explicitly noted as a risk in the project's own handoff notes). Ruled out.

**Integration tests against a test tenant** — Correct but expensive: requires a test tenant, service principal, secret rotation, and data seeding. Out of scope for the current team size.

**No tests at all** — The 1.0.0 approach. Resulted in the broken manifest reaching the Gallery. Eliminated.

---

## Consequences

- CI is fast (under 2 seconds for the test suite) and cheap (no API calls).
- Behavioural correctness (e.g. "does `offboard-user` actually block sign-in?") is not tested in CI. Engineers are expected to smoke-test against a real tenant before major releases.
- The tests catch the specific class of bugs that have actually broken this project: manifest drift, syntax errors, broken CHANGELOG.
- `Test-ModuleManifest` in the tests requires that the declared `RequiredModules` are installed in the CI runner. The GitHub Actions workflow installs `ExchangeOnlineManagement` before running Pester. If a new required module is added to the manifest, the workflow's "Install dependencies" step must be updated to match.

---

## Related files

- `tests/Module.Tests.ps1` — the full test suite
- `.github/workflows/verify.yml` — CI workflow that runs Pester and PSScriptAnalyzer
- `Publish.ps1` — the same checks run before every Gallery publish
