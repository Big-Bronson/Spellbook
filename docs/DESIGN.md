# Spellbook — Design Document

**Audience:** Someone learning how this module is built, why it was built that way, and what to keep in mind when extending it.

---

## What this is

Spellbook is a PowerShell module published to the PowerShell Gallery. It gives MSP helpdesk engineers a consistent, numbered CLI for common Microsoft 365 tasks — creating users, offboarding, managing mailbox permissions, auditing MFA, running tenant reports.

The problem it solves: an MSP engineer logs into a customer tenant and needs to do five different things. Without Spellbook, they open five different browser tabs, five sets of documentation, and type five different PowerShell cmdlets from memory. With Spellbook, they type `invoke` and pick from a numbered list.

```
  Spellbook
  invoke <command>  |  invoke <number>

  User Lifecycle:
   1. new-user                         Create a new M365 user and assign groups
   2. offboard-user                     Full offboarding — block, wipe, convert, log
   3. set-userlicence                   Assign or remove a licence from a user

  User Reports & Auditing:
   4. get-userreport                    Full profile dump for a single user
   ...
```

The goal is not to hide complexity — it is to make the right thing the easy thing.

---

## The big picture

```
PowerShell session
│
├── Import-Module Spellbook
│     │
│     ├── Spellbook.psm1  (loads everything)
│     │     ├── Dot-sources every Public/*.ps1 as a global function
│     │     └── Defines invoke()
│     │
│     └── Spellbook.psd1  (manifest: version, exports, dependencies)
│
└── Engineer types: invoke offboard-user
      │
      └── invoke() dot-sources Public/offboard-user.ps1 into the session
            │
            ├── Connects to Exchange Online (if not already)
            ├── Connects to Microsoft Graph (if not already)
            ├── Prompts for the UPN
            └── Runs all offboarding steps
```

There are also two files that live outside the module boundary:

- **`Publish.ps1`** — the publisher. Run this when you want to push a new version to PS Gallery.
- **`invoke-profile.ps1`** — a standalone version of the Spellbook menu that engineers paste into their `$PROFILE`. Used without installing the module.
- **`Install.ps1`** — a bootstrap script. Clones the repo and installs the module dependencies.

---

## The dispatch model

The central design question was: *how do you make a collection of independent scripts feel like a single coherent tool?*

The answer is dot-sourcing.

### What dot-sourcing means

Normal script invocation (`& ".\script.ps1"`) runs the script in a child scope and throws the results away when it finishes. The script's variables, functions, and connections disappear.

Dot-sourcing (`. ".\script.ps1"`) runs the script in the *current* scope. Everything the script creates — variables, functions, connections — persists in the caller's session after the script completes.

This matters because MSP engineers use Spellbook interactively. They connect to Exchange Online, run a few commands, and don't want to re-authenticate for every command. Dot-sourcing lets each script check whether a connection already exists and skip the auth step if it does.

### How the module sets this up

When the module loads (`Spellbook.psm1`), it does something clever: it wraps each Public script in a one-line function that dot-sources it:

```powershell
Get-ChildItem -Path $PublicPath -Filter "*.ps1" | ForEach-Object {
    $funcName  = $_.BaseName
    $scriptPath = $_.FullName
    $funcBlock = [scriptblock]::Create(". `"$scriptPath`"")
    Set-Item -Path "function:global:$funcName" -Value $funcBlock
}
```

So after `Import-Module Spellbook`, typing `offboard-user` at the prompt directly runs `Public/offboard-user.ps1` in the engineer's session scope. The function name *is* the script filename without the `.ps1` extension.

### How invoke() dispatches

`invoke()` is a second layer — it provides the numbered menu and name-based lookup. When the engineer types `invoke offboard-user` or `invoke 2`:

```powershell
if ($commands.Contains($Command)) {
    $scriptFile = Join-Path (Join-Path $PSScriptRoot "Public") "$Command.ps1"
    if (Test-Path $scriptFile) {
        . $scriptFile   # ← dot-source, not &
    }
}
```

It resolves the command name to the script path and dot-sources it directly. Same effect as calling `offboard-user` directly — both end up in the engineer's scope.

### The critical consequence: `return`, never `exit`

Because scripts run in the caller's scope, `exit` is catastrophic. It does not exit the script — it exits the PowerShell *session*. The engineer's window closes.

Every early-termination path in every Public script uses `return`:

```powershell
# Correct
if (-not $user) {
    Write-Host "User not found: $upn" -ForegroundColor Red
    return   # exits the script, session survives
}

# Wrong — closes the engineer's terminal
if (-not $user) {
    Write-Host "User not found: $upn" -ForegroundColor Red
    exit     # DO NOT DO THIS
}
```

This was not obvious from the start. The initial release used `exit` in eight places across five scripts. A portability fix commit (`33f89e2`) caught and corrected all of them. The pattern is now established: if you see `exit` in a Public script, it is a bug.

---

## How scripts connect to Microsoft services

Each script is self-contained. It does not assume that the caller has already connected to Graph or Exchange — it checks and connects itself. It also requests only the Graph scopes it actually needs.

```powershell
# At the top of new-user.ps1
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.Read.All" `
        -ContextScope Process
}

# At the top of get-allusers.ps1
if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline }
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All" -ContextScope Process
}
```

The `-ContextScope Process` flag on Graph connections scopes the token to the current process rather than the broader user context. This prevents a connection in one session from interfering with another.

The pattern `if (-not (Get-MgContext))` means: if there is already an active Graph connection (from a previous command in the same session), skip the `Connect-MgGraph` call entirely. The engineer authenticates once and the session stays live.

**Why not a global connection function?** Because each script needs different scopes. `get-userreport` needs `User.Read.All`. `offboard-user` needs `UserAuthenticationMethod.ReadWrite.All`, `RoleManagement.ReadWrite.Directory`, and more. A single global connection would either request all scopes for every command (wasteful, triggers a wide-permission prompt) or not request enough scopes for some commands (silent failures). Per-script connections are the right trade-off.

---

## The Microsoft Graph SDK v2 property trap

This is the most common source of silent bugs when writing Graph scripts.

The Microsoft Graph PowerShell SDK v2 changed the default behaviour of `Get-MgUser`. Without `-Property`, it returns only `Id` and `DisplayName`. If your script then reads `$user.AccountEnabled` or `$user.AssignedLicenses`, those properties are `$null` — not because the user has no licences, but because you never asked for them.

The failure is completely silent. The script appears to work but produces wrong output.

The rule is simple: every `Get-MgUser` call declares exactly which properties it reads:

```powershell
# Wrong — other properties will be $null
$user = Get-MgUser -Filter "userPrincipalName eq '$upn'"

# Correct
$user = Get-MgUser -Filter "userPrincipalName eq '$upn'" `
    -Property "Id,DisplayName,AccountEnabled,AssignedLicenses,UserPrincipalName"
```

This applies to other `Get-Mg*` cmdlets too. `Get-MgSubscribedSku` is another common one.

The benefit of this discipline is that each script's `-Property` list is a readable declaration of exactly what data it depends on. When you add a new property access to a script, you must also add it to `-Property` — that friction is intentional.

---

## The password security pattern

When a script needs the engineer to type a password (for example, `new-user.ps1` asks for the new account's initial password), it does not use plain `Read-Host`. Plain `Read-Host` echoes the typed characters to the terminal and stores them in a regular string in memory.

Instead:

```powershell
$securePw = Read-Host "Initial password" -AsSecureString

# Convert at the point of use only
$plainPw = [System.Net.NetworkCredential]::new('', $securePw).Password

try {
    $newUser = New-MgUser -PasswordProfile @{ Password = $plainPw; ... }
} finally {
    $plainPw = $null   # clear immediately
}
```

`-AsSecureString` reads the password into an encrypted in-memory object. The characters are never visible in the terminal. The plain-text conversion happens only at the exact call site that needs it, and `$plainPw` is nulled in a `finally` block immediately after. If the API call throws an exception, the `finally` still runs, so the plain text is not left dangling in memory.

The summary shown after creating the user confirms the password was set without revealing it:

```
Password:     (set — not echoed)
```

---

## The portable password generator

`offboard-user.ps1` generates a random password to lock out the departing user. Generating cryptographically random passwords in PowerShell has a cross-version trap.

`[System.Web.Security.Membership]::GeneratePassword()` works fine in Windows PowerShell 5.1 (which ships with Windows) but is not available in PowerShell 7 — `System.Web` is a .NET Framework assembly, not available in the cross-platform .NET runtime.

The module must support both because engineers use both. The solution is a portable generator built on `System.Security.Cryptography.RandomNumberGenerator`, which exists in both runtimes:

```powershell
function New-OffboardPassword {
    param([int]$Length = 20)
    $upper = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lower = [char[]]'abcdefghjkmnpqrstuvwxyz'
    $digit = [char[]]'23456789'
    $sym   = [char[]]'!@#$%^&*-_=+'
    $all   = @($upper + $lower + $digit + $sym)
    $rng   = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $buf   = [byte[]]::new(4)
    $pick  = { param($pool) $rng.GetBytes($buf); $pool[[BitConverter]::ToUInt32($buf,0) % $pool.Length] }

    $chars = [System.Collections.Generic.List[char]]::new()
    $chars.Add((& $pick $upper))
    $chars.Add((& $pick $lower))
    $chars.Add((& $pick $digit))
    $chars.Add((& $pick $sym))
    while ($chars.Count -lt $Length) { $chars.Add((& $pick $all)) }

    # Fisher-Yates shuffle so the guaranteed classes aren't always first
    for ($i = $chars.Count - 1; $i -gt 0; $i--) {
        $rng.GetBytes($buf)
        $j = [int]([BitConverter]::ToUInt32($buf, 0) % [uint32]($i + 1))
        $tmp = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $tmp
    }
    -join $chars
}
```

The generator guarantees one character from each of the four M365 complexity classes (upper, lower, digit, symbol), then fills the remaining length from the combined pool, and shuffles the result so the guaranteed characters are not predictably positioned.

---

## Last-login data without Entra P1

Several commands need to report when a user last had activity — `get-allusers`, `get-inactiveusers`, `get-userreport`.

The obvious API is `Get-MgAuditLogSignIn` (Entra sign-in logs). It provides rich detail: IP address, application, conditional access outcome, exact timestamp. However, accessing sign-in logs requires `AuditLog.Read.All`, which in turn requires an Entra ID P1 or P2 licence. Many SMB tenants managed by MSP engineers are on Microsoft 365 Business Basic or E1 — no Entra P1.

A tool that silently fails on half the tenants it's supposed to support is not useful. So these commands use Exchange mailbox statistics instead:

```powershell
$mailboxStats = Get-MailboxStatistics -ResultSize Unlimited |
    Select-Object DisplayName, UserPrincipalName, LastLogonTime
```

`Get-MailboxStatistics` returns the last time the mailbox was accessed by any mail client. It requires only Exchange Online, which is included in all Microsoft 365 plans. No premium licence needed.

The trade-off: this reflects mailbox access only, not Teams activity, SharePoint, or app sign-ins. A user who works entirely in Teams but never opens email appears inactive. This is documented in the command comments. The `get-signinlogs` command, which *does* require Entra P1, documents that requirement explicitly in its header and is treated as a specialist command.

---

## Log accumulation and the O(n²) trap

Several scripts iterate over all users or all mailboxes and accumulate a list of results to export as CSV at the end. The idiomatic PowerShell approach is array concatenation:

```powershell
$log = @()
foreach ($user in $users) {
    $log += [PSCustomObject]@{ ... }  # DO NOT DO THIS in a long loop
}
```

This looks innocent but is quadratic. PowerShell arrays are fixed-size. `$log += $entry` creates a *new* array on every iteration, copies all existing elements into it, then adds the new one. For 500 users, that copies approximately 125,000 objects total. For 2,000 users (a realistic MSP tenant), it copies 2 million objects.

The correct pattern uses `[System.Collections.Generic.List[PSCustomObject]]`:

```powershell
$log = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($user in $users) {
    $log.Add([PSCustomObject]@{ ... })
}
```

A generic list allocates a backing array and doubles its capacity geometrically when it fills — amortised O(1) per insert, O(n) total. For 500 users, the list reallocates roughly nine times. `Export-Csv` and `Format-Table` both accept it directly, so no conversion is needed before export.

Every script with a per-item loop uses this pattern. If you see `$log += ...` in a new script, replace it.

---

## Output conventions

### Colour coding

All user-facing output uses `Write-Host` with a consistent colour scheme:

| Colour | Meaning |
|--------|---------|
| `Green` | Success, action completed |
| `Red` | Error, failure |
| `Yellow` | Warning, prompt, something to pay attention to |
| `DarkGray` | Informational, secondary detail |
| `Cyan` | Headers, highlights, final results |

### Step status strings

Multi-step scripts (offboarding, the calendar events loop) report every step with one of three status strings: `OK`, `FAILED`, or `SKIPPED`. These are printed in brackets and written to the CSV `Status` column:

```
  [OK] Block sign-in
  [OK] Reset password — New password: Xk9$mLp...
  [SKIPPED] Set Out of Office — No message provided
  [FAILED] Cancel future calendar events — The user mailbox was not found
```

The implementation in `offboard-user.ps1`:

```powershell
function Log-Action {
    param($Step, $Status, $Notes = "")
    $entry = [PSCustomObject]@{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        UPN       = $upn
        Step      = $Step
        Status    = $Status
        Notes     = $Notes
    }
    $log.Add($entry)
    $colour = if ($Status -eq "OK") { "Green" } elseif ($Status -eq "SKIPPED") { "DarkGray" } else { "Red" }
    Write-Host "  [$Status] $Step$(if ($Notes) { " — $Notes" })" -ForegroundColor $colour
}
```

Why fixed strings rather than descriptive text in the Status column? Because the CSV is used for audit trails and ticket attachments. A column with fixed values can be filtered: `Where-Object { $_.Status -eq "FAILED" }` extracts every step that needs follow-up. Free-form status text cannot be filtered reliably.

`SKIPPED` means the step was intentionally not run — either a pre-condition was already met (the mailbox already had calendar events disabled) or the operator declined an optional step (no OOO message). It is not a failure.

### CSV on the Desktop

Scripts that produce audit logs write a timestamped CSV to `$env:USERPROFILE\Desktop`:

```powershell
$path = "$env:USERPROFILE\Desktop\Offboard_$($upn.Split('@')[0])_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"
$log | Export-Csv -Path $path -NoTypeInformation
```

The Desktop is intentional. Engineers need the log immediately accessible — to attach to a ticket, to check at a glance. Putting it in a subfolder or a path they have to remember to navigate to adds friction.

---

## Safety patterns

### The tenant-wide confirmation gate

Some commands affect an entire tenant. `disable-autocalevents.ps1` reaches into every mailbox. Running it against the wrong tenant would require manually re-enabling hundreds of mailboxes.

These commands require the operator to type the tenant's primary domain before doing anything:

```powershell
$org          = Get-MgOrganization
$tenantName   = $org.DisplayName
$primaryDomain = ($org.VerifiedDomains | Where-Object { $_.IsDefault }).Name

Write-Host "  Tenant: $tenantName" -ForegroundColor Cyan
Write-Host "  Domain: $primaryDomain" -ForegroundColor Cyan

$typed = Read-Host "Type the primary domain ($primaryDomain) to confirm"
if ($typed -ne $primaryDomain) {
    Write-Host "Confirmation failed. Aborted." -ForegroundColor Red
    return
}
```

The reason this works as a safety mechanism: the engineer has to have the correct domain in front of them to proceed. They cannot accidentally confirm by pressing Enter or typing "y". They have to type the actual domain, which forces them to read and verify which tenant they're connected to.

Any new command that affects an entire tenant should follow this pattern. Commands that affect a single user or mailbox do not need it — the user identity prompt and the subsequent display of the user's name before the operation begins is sufficient confirmation.

---

## The module manifest and dependency pinning

`Spellbook.psd1` serves two purposes: it tells PowerShell what the module exports, and it tells the PS Gallery what the module is.

### FunctionsToExport — the contract

`FunctionsToExport` lists every function that becomes available when the module is imported. It must exactly match the Public scripts:

```powershell
FunctionsToExport = @(
    'invoke'
    'new-user'
    'offboard-user'
    'set-userlicence'
    # ... one entry per Public/*.ps1, plus invoke
)
```

If a script exists in `Public/` but is not in this list, the module imports without it — engineers cannot call it. If a name is in this list but has no corresponding `.ps1`, calling it produces "Script not found" from `invoke()` — confusing and embarrassing.

The 1.0.0 release had both problems. Seventeen functions were declared that did not exist. The 1.0.1 fix trimmed the list to match reality and moved unbuilt commands to a "Planned" section in the README.

The Pester test suite and `Publish.ps1` both enforce this: they compare `FunctionsToExport` against the actual files in `Public/` and fail if they diverge.

### RequiredModules — minimum version floors

```powershell
RequiredModules = @(
    @{ ModuleName = 'ExchangeOnlineManagement'; ModuleVersion = '3.0.0' }
    @{ ModuleName = 'Microsoft.Graph.Users';    ModuleVersion = '2.0.0' }
    @{ ModuleName = 'Microsoft.Graph.Identity.SignIns'; ModuleVersion = '2.0.0' }
)
```

`ModuleVersion` in a `RequiredModules` entry means *minimum version*, not exact version. The module loads if the installed version is equal to or greater than the declared version.

The floors are set at major version boundaries where breaking changes occurred: Exchange Online v3 rewrote the connection model; Graph v2 changed authentication and the `-Property` default behaviour. Anything below those floors would fail at runtime with confusing cmdlet-not-found errors.

Exact version pinning was rejected because MSP engineers work on managed machines where IT controls which versions of modules are installed. Pinning to an exact version would refuse to load if that exact version is not present, even if a newer compatible version is. Minimum pinning lets the module use whatever compatible version is already there.

---

## The publish pipeline

### Publish.ps1 — pre-flight checks

`Publish.ps1` is not just a wrapper around `Publish-Module`. Before publishing, it runs five checks and aborts on any failure:

1. **Manifest validation** — `Test-ModuleManifest` confirms the `.psd1` is well-formed.
2. **Parse check** — every `Public/*.ps1` is parsed through the PowerShell AST parser. A syntax error in any script blocks the publish.
3. **FunctionsToExport sync** — the declared functions and the actual files are compared both ways. A new script without a manifest entry, or a manifest entry without a script, blocks the publish.
4. **Git working tree** — the working tree must be clean and on `main`. Prevents publishing uncommitted changes or from a feature branch.
5. **CHANGELOG** — `CHANGELOG.md` must have content under `[Unreleased]`. Publishing without release notes is blocked.

The API key is read from Windows Credential Manager (preferred for regular publishers) with a fallback to an environment variable (for CI or one-off use).

Run with `-WhatIf` to exercise all checks without actually publishing:

```powershell
.\Publish.ps1 -WhatIf
```

### CI — Pester + PSScriptAnalyzer

Every push to `main` and every pull request runs two GitHub Actions jobs.

**Pester tests** (`tests/Module.Tests.ps1`) run the same checks as `Publish.ps1`, plus more. They verify:
- The manifest parses and has a version
- `ProjectUri` and `LicenseUri` point at the actual repo (a regression from 1.0.0)
- `FunctionsToExport` and `Public/` are in sync both ways
- Every `Public/*.ps1` parses without errors (one test per script, parameterised)
- `CHANGELOG.md` has an `[Unreleased]` section and a dated section matching the manifest version

**PSScriptAnalyzer** runs in two passes. Errors block the build — these are genuine correctness issues. Warnings are advisory and do not fail the build, because the existing scripts deliberately use things like `Write-Host` that the analyser flags stylistically but that are correct for a CLI tool.

The distinction matters: `Write-Host` in a module library that other code might import is a problem (it bypasses the pipeline). In a script that runs interactively in a terminal, it is the right tool — it gives the engineer coloured, formatted output.

---

## What to look for when adding a command

When you add a new Public script, there are seven things that must stay in sync:

| Location | What to add |
|----------|-------------|
| `Public/your-command.ps1` | The script itself |
| `Spellbook.psm1` | Entry in `$commands` ordered hashtable |
| `Spellbook.psm1` | Entry in `$sectionHeaders` if it opens a new section |
| `invoke-profile.ps1` | Same entry in its `$commands` hashtable |
| `Spellbook.psd1` | Entry in `FunctionsToExport` |
| `README.md` | Row in the command table |
| `CHANGELOG.md` | Entry under `[Unreleased]` |

The Pester tests will catch a missing `FunctionsToExport` entry. The CI will catch a parse error in the script. But the `invoke-profile.ps1` and `README.md` updates are not tested — they require discipline.

### The checklist for the script itself

- **Top of script:** check and connect to Graph and/or Exchange as needed, with only the scopes the script reads
- **`Get-MgUser` calls:** always include `-Property` with an explicit list
- **Early exits:** always `return`, never `exit`
- **Passwords typed by the operator:** `Read-Host -AsSecureString`, convert at point of use, null in `finally`
- **Accumulating results in a loop:** `[System.Collections.Generic.List[PSCustomObject]]::new()` and `.Add()`, not `$log += ...`
- **Per-step status:** `OK`, `FAILED`, or `SKIPPED` — colour-matched consistently
- **CSV output:** `$env:USERPROFILE\Desktop\CommandName_$(Get-Date -Format 'yyyyMMdd_HHmm').csv`
- **Tenant-wide commands:** require typing the primary domain before proceeding

---

## The ordered hashtable quirk

`invoke()` stores the command list in an `[ordered]@{}` (an `OrderedDictionary`). Ordered dictionaries maintain insertion order, which is why the menu always appears in the same sequence.

However, `OrderedDictionary` is not a regular hashtable. It does not have a `.ContainsKey()` method — that method exists only on `Hashtable`. Calling `.ContainsKey()` on an ordered dictionary throws an `InvalidOperation` error at runtime.

The correct method is `.Contains()`:

```powershell
# Wrong — throws at runtime on [ordered] hashtables
if ($commands.ContainsKey($Command)) { ... }

# Correct
if ($commands.Contains($Command)) { ... }
```

This caught Spellbook in production (1.0.0 release). Any command lookup against `$commands` must use `.Contains()`. Both `Spellbook.psm1` and `invoke-profile.ps1` were patched.

---

## The dual distribution model

The module ships in two forms.

**Published module** (`Install-Module Spellbook`): the standard PowerShell Gallery installation. Requires `Install-Module` access, an internet connection, and the three `RequiredModules` to be present. Installs into the module path. Engineers use `Import-Module Spellbook` in their profile.

**Profile snippet** (`invoke-profile.ps1`): a standalone function definition the engineer pastes directly into their `$PROFILE`. No module installation required. The function points at a local copy of the scripts folder. This is for engineers on locked-down machines where they cannot run `Install-Module`, or who want Spellbook available before the module is installed.

The two distributions must stay in sync. When a new command is added, both the psm1 command table and the profile snippet's command table need the entry. When the Spellbook menu structure changes, both need updating.

---

## Where the decisions are documented

The `docs/decisions/` directory contains Architecture Decision Records (ADRs) — one file per significant decision. They are numbered chronologically from when the decision was first made.

The first nine (0001–0009) all originate from the initial release. The rest were introduced by specific commits you can trace in `git log`:

- **0010–0011**: the `OrderedDictionary` bug discovery and Publish.ps1 rewrite
- **0012**: the 1.0.1 manifest cleanup
- **0013**: the `disable-autocalevents` tenant confirmation gate
- **0014–0015**: the CI pipeline addition
- **0016–0018**: the portability fix (`exit` → `return`, CSPRNG, SecureString)

Each ADR has a **Context** (what situation prompted it), **Decision** (the rule), **Rationale** (the mechanism behind the choice), **Alternatives Considered** (what else was evaluated and why it was rejected), and **Consequences** (what the decision costs and constrains going forward).

When you make a decision that is not obvious from reading the code — a compatibility constraint, a trade-off between two valid approaches, a gotcha from an external API — write an ADR. The goal is that no future reader ever has to reverse-engineer the "why" from the code alone.
