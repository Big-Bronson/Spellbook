# ADR-0015: PSScriptAnalyzer errors block CI; warnings are advisory

**Date:** 2026-05-08  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

When PSScriptAnalyzer was added to the GitHub Actions workflow (`verify.yml`), a decision was needed about how strict to be. Running the full analyser and failing on all findings would have required significant script refactoring — in particular, `Write-Host` generates a warning ("Use Write-Output instead of Write-Host"), but `Write-Host` is intentional in this project because its output cannot be captured or redirected, which is exactly the desired behaviour for an interactive CLI tool.

---

## Decision

The CI lint job runs PSScriptAnalyzer in **two steps**:

1. **Errors only** (`-Severity Error`) — if any Error-level finding exists, the build fails. These indicate genuine defects: syntax issues, undefined variables, broken pipelines.
2. **Warnings** (`-Severity Warning`) — run with `continue-on-error: true`. Findings are printed to the CI log for visibility but do not fail the build.

```yaml
- name: Lint (errors only)
  run: |
    $results = Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
    if ($results) { $results | Format-Table -AutoSize; exit 1 }

- name: Lint (warnings, advisory)
  continue-on-error: true
  run: |
    Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning | Format-Table -AutoSize
```

---

## Rationale

**`Write-Host` is intentional:** The project's CLAUDE.md and coding conventions explicitly require `Write-Host -ForegroundColor` for all user-facing output. The PSScriptAnalyzer warning about `Write-Host` is valid in general PowerShell but incorrect for this project's context. Making warnings block CI would require either suppressing this rule project-wide or refactoring every script — neither is worthwhile.

**Errors are non-negotiable:** Error-level findings in PSScriptAnalyzer represent real bugs (e.g. `PSPossibleIncorrectUsageOfRedirectionOperator`, `PSAvoidUsingPositionalParameters` at Error level). These should never reach the Gallery.

**Keeping warnings visible:** Running the warning-level scan as advisory (not blocking) keeps the output available in CI logs. A contributor can look at the lint step and see what stylistic issues exist, without being blocked by them.

---

## Alternatives considered

**Fail on all severities** — Would require suppression attributes on every `Write-Host` call, or a project-wide suppress rule. High noise, low signal. Ruled out.

**Skip PSScriptAnalyzer entirely** — Would miss real error-level bugs. Ruled out.

**Custom ruleset excluding `Write-Host` warning** — More precise, but requires maintaining a PSScriptAnalyzer settings file. The two-step approach achieves the same effect without the extra config file.

---

## Consequences

- Real defects (Error level) are caught before they reach the Gallery.
- `Write-Host` warnings appear in every CI run's advisory step. This is expected and can be ignored.
- If a new genuine warning-level issue appears (e.g. a security-relevant finding), it will appear in logs but not block the build. The team needs to actively check the advisory step output, not just rely on the build passing.

---

## Related files

- `.github/workflows/verify.yml` — the two lint steps
