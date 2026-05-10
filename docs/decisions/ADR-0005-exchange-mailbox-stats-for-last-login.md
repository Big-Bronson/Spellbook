# ADR-0005: Use Exchange mailbox statistics for last-login activity, not Entra sign-in logs

**Date:** 2026-05-07  
**Status:** Accepted  
**Decider:** Steve Vella

---

## Context

Several commands need to report when a user last had mailbox activity — `get-allusers`, `get-inactiveusers`, and the user-report command. The natural Graph API for this is `Get-MgAuditLogSignIn`, which provides full sign-in history with IP addresses, conditional access outcomes, and application-level detail. However, `AuditLog.Read.All` sign-in logs **require Entra ID P1 or P2 licensing** (or Microsoft 365 Business Premium). Many SMB tenants managed by MSP engineers are on basic Microsoft 365 Business Basic or E1 licences and do not have Entra P1.

---

## Decision

Commands that report on user activity use **`Get-MailboxStatistics`** from Exchange Online (specifically `LastLogonTime`) rather than Entra sign-in logs. This requires only an Exchange Online licence (included in all M365 plans) and no Entra premium licence.

The comment in `get-signinlogs.ps1` explicitly notes the Entra P1 requirement because that command has no Exchange-based alternative — it is a specialist command where the engineer knows premium logging is available.

---

## Rationale

**The module must work on the tenants MSP engineers actually manage.** A significant proportion of SMB tenants have basic M365 licences. A tool that requires Entra P1 to report basic user activity would be useless on those tenants.

`Get-MailboxStatistics -LastLogonTime` reflects the last time a user's mailbox was accessed by any mail client (Outlook, OWA, mobile). For the purpose of identifying inactive users or producing an all-users report, this is sufficient.

---

## Alternatives considered

**`Get-MgAuditLogSignIn`** — Full sign-in detail, but requires Entra P1/P2. Would fail silently or with an auth error on unlicensed tenants. Ruled out for general activity commands.

**`Get-MgUserActivity` / Microsoft 365 usage reports** — These exist in `Microsoft.Graph.Reports` and provide 30/90-day aggregates. Useful for broad reporting but not for a per-user last-login timestamp. Not granular enough for `get-inactiveusers`.

**`LastSignInDateTime` on `Get-MgUser`** — Available without Entra P1 for the user's own last sign-in, but populated only if sign-in occurred after a certain date cutoff and can be several hours stale. Less reliable than `LastLogonTime` from EXO.

---

## Consequences

- Activity data reflects mailbox access only, not app sign-ins, SharePoint access, or Teams activity. A user who uses Teams but never opens email would appear inactive. This is documented behaviour — the `get-allusers` comment reads "No Entra P1/P2 required. Uses Exchange mailbox stats for last activity."
- Commands that use this approach require Exchange Online connection, not just Graph.
- `get-signinlogs` is explicitly carved out as a premium-only command and documents this in its header comment.

---

## Related files

- `Public/get-allusers.ps1` — uses `Get-MailboxStatistics` explicitly, notes no P1 required
- `Public/get-inactiveusers.ps1` — same approach
- `Public/get-signinlogs.ps1` — explicitly notes the Entra P1 requirement
