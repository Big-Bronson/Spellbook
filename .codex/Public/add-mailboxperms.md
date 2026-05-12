## Public/add-mailboxperms.ps1

### What This File Does

This script is an interactive command-line tool that grants delegated mailbox access to a user in Exchange Online. It prompts for a target mailbox and a trustee user, validates both exist, then asks which permissions to grant (Full Access and/or Send As), and applies those permissions using Exchange cmdlets. It's part of a three-function permissions suite alongside get-mailboxperms and get-userperms.

### Why It Exists

Exchange Online permissions are complex and error-prone to grant via raw cmdlet calls—the operations use different cmdlets (Add-MailboxPermission vs. Add-RecipientPermission), have different parameter names (User vs. Trustee), and involve user decisions like auto-mapping. This script centralizes that workflow, validates inputs before acting, and surfaces results clearly so admins can confidently delegate mailbox access without consulting documentation or making typos.

### What It Protects Against

- **Invalid mailbox identity**: Validates the target mailbox exists before attempting to grant permissions, preventing silent failures or confusing error messages.
- **Invalid trustee identity**: Checks that the user exists in Exchange before submitting permission requests, avoiding orphaned or unresolvable permissions.
- **No-op requests**: Detects when a user selects neither Full Access nor Send As and exits without making unnecessary API calls.
- **Missing Exchange connection**: Auto-connects to Exchange Online if not already connected.
- **Partial failures**: Uses try-catch blocks to isolate Full Access and Send As operations, so one can fail independently without masking the other.

### Invariants

- Exchange Online PowerShell module must be available (connection is auto-attempted).
- Identity and trustee parameters must resolve to valid Exchange objects.
- At least one permission type (Full Access or Send As) must be selected for the script to proceed.
- The user running this script must have permissions to call Add-MailboxPermission and Add-RecipientPermission in the tenant.

### Key Patterns

- **Interactive prompts**: Uses Read-Host to gather input in a conversational flow rather than script parameters, making it discoverable and forggiving for ad-hoc use.
- **Validation-before-action**: Validates both mailbox and trustee before prompting for permission choices, reducing wasted input.
- **Conditional auto-mapping**: Only asks about auto-mapping if Full Access is chosen, avoiding irrelevant questions.
- **Independent permission blocks**: Full Access and Send As are granted in separate try-catch blocks, so failure of one doesn't prevent the other from being attempted.
- **Color-coded output**: Uses green for success, red for errors, and cyan for confirmation, providing visual feedback without verbose logging.

### Change Log

- 2026-05-08: Initial commit adding mailbox permissions family (get-mailboxperms, get-userperms, add-mailboxperms).