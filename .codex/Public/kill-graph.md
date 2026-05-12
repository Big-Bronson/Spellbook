## Public/kill-graph.ps1

### What This File Does
Cleanly disconnects the current PowerShell session from Microsoft Graph and reports the outcome to the operator. It is a utility command that sits alongside other Microsoft Graph-dependent scripts and handles the session lifecycle reset that those scripts require.

### Why It Exists
Microsoft Graph PowerShell maintains a persistent session token for the life of the PowerShell process. Once `Connect-MgGraph` runs with a specific scope list, that token is reused on all subsequent Graph calls—even if a different script later calls `Connect-MgGraph` with a broader scope request. Engineers need a way to explicitly tear down that session when they need to re-authenticate with different scopes, switch tenants, or invalidate the token at session end. This script provides that reset mechanism.

### What It Protects Against
The original two-line implementation called `Disconnect-MgGraph` unconditionally, which threw a terminating error when no active session existed ("There is no active Microsoft Graph session"). This error surfaced as a confusing red exception trace to the operator, even though the desired end state (no active session) was already achieved. This version guards against that by checking `Get-MgContext` first and returning early with a friendly message if no session is present. It also wraps the disconnect in try/catch to catch transient network or SDK errors during token revocation and surface them as normal (non-exception) output.

### Invariants
- `Microsoft.Graph.Authentication` module must be loaded for `Get-MgContext` and `Disconnect-MgGraph` to be available.
- Execution must use `return` rather than `exit` to avoid terminating the operator's entire PowerShell session when invoked as a dot-sourced script (per ADR-0016).
- The function is idempotent: calling it when no session exists is a no-op with informational output, not an error.

### Key Patterns
**Defensive guards**: The script checks state (`Get-MgContext`) before taking action rather than letting the downstream cmdlet throw. **Contextual messaging**: The disconnect message includes the tenant ID, account, or a generic phrase depending on what context fields are populated. **Exception wrapping**: The actual `Disconnect-MgGraph` call is wrapped in try/catch to convert SDK errors into user-friendly red text instead of raw exception traces. **Null-safe output suppression**: Pipe to `Out-Null` to prevent cmdlet output from cluttering the operator's terminal.

### Change Log
- 2026-05-11: Release 1.1.0: V2 mailflow, expanded RequiredModules, audit-log integrity
- 2026-05-08: feat: add kill-graph; add Pester smoke tests (#5)