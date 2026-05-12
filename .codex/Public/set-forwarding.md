## Public/set-forwarding.ps1

### What This File Does
This script configures email forwarding on an Exchange Online mailbox by prompting a user for a source mailbox and destination email address, validating both exist in the organization, asking whether to keep a local copy of forwarded mail, and then applying the forwarding rule with user confirmation.

### Why It Exists
Setting up mail forwarding requires multiple Exchange Online cmdlets and validation steps that are error-prone when done manually. This script bundles the validation logic, confirmation workflow, and configuration into a single interactive command so administrators can safely forward mailboxes without typos or misconfiguration.

### What It Protects Against
The script defends against four concrete failure modes: (1) attempting to configure forwarding on a non-existent source mailbox, (2) forwarding to an address that doesn't exist in Exchange (which would silently fail or bounce mail), (3) accidentally overwriting an existing forwarding rule without noticing, and (4) accidentally applying the wrong settings by requiring explicit yes/no confirmation before executing the change.

### Invariants
- An active Exchange Online connection must exist or be establishable at runtime
- The source mailbox identifier (UPN or SMTP address) must resolve to exactly one mailbox
- The destination address must resolve to a valid Exchange recipient
- User must explicitly confirm the configuration before it is applied
- The `DeliverToMailboxAndForward` parameter must be set to the boolean result of the keep-copy prompt

### Key Patterns
**Interactive validation**: The script asks for input, validates each piece independently, then summarizes everything and asks for final approval. This prevents silent failures and gives the user a chance to spot mistakes. **Connection lazy-loading**: It checks for an existing Exchange connection before establishing one, avoiding unnecessary re-authentication. **Overwrite warning**: It detects and displays existing forwarding rules in yellow to make destructive changes visible. **Structured error handling**: Each major operation (mailbox lookup, recipient lookup, rule application) has its own try-catch block with specific error messages.

### Change Log
- 2026-05-08: Initial commit adding set-forwarding script with source and destination validation, keep-copy prompt, and confirmation workflow.