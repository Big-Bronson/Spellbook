## Public/remove-forwarding.ps1

### What This File Does
This script disables email forwarding on an Exchange Online mailbox by clearing the forwarding address and preventing mail from being delivered to both the original mailbox and the forwarding destination simultaneously. It's an interactive utility that prompts for a mailbox identity, shows the current forwarding configuration, and requires explicit user confirmation before making changes.

### Why It Exists
Email forwarding rules can become stale, misconfigured, or create security risks if left unmanaged. Administrators need a straightforward way to cleanly remove forwarding rules without having to directly manipulate Exchange cmdlets or remember which properties must be reset together (both `ForwardingSMTPAddress` and `DeliverToMailboxAndForward`).

### What It Protects Against
The script defends against several failure modes: (1) attempting to modify a mailbox that doesn't exist by validating the identity upfront, (2) accidentally removing forwarding when none is configured by checking if the current forwarding address is empty, (3) accidental removal through explicit y/n confirmation, and (4) partial state corruption by setting both the forwarding address and the delivery-to-both-locations flag in a single atomic operation.

### Invariants
- An Exchange Online connection must exist before execution (the script connects if needed)
- The provided identity must resolve to a valid mailbox
- A non-empty `ForwardingSMTPAddress` must exist before removal is attempted
- User confirmation (typing "y") must be given before any mailbox modification occurs

### Key Patterns
**Early validation and early return**: The script checks for mailbox existence and current forwarding state upfront, exiting with context-specific messages rather than proceeding to doomed operations. **User confirmation gate**: A blocking y/n prompt prevents accidental execution. **Paired property reset**: Both `ForwardingSMTPAddress` and `DeliverToMailboxAndForward` are set together, since setting one without the other leaves the mailbox in an ambiguous state.

### Change Log
- 2026-05-08: Initial addition as part of forwarding management toolset.