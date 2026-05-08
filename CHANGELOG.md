# Changelog

All notable changes to StevesScriptorium will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [Unreleased]

### Fixed
- `toolkit` command lookup now uses `.Contains()` instead of `.ContainsKey()` on `[ordered]` hashtables — fixes `InvalidOperation` crash when running any named command

### Added
- `CLAUDE.md` — shared project context for Claude Code sessions
- `get-inactiveusers` command
- `get-licensedusers` command listed in toolkit menu

### Changed
- `Publish.ps1` rewritten with pre-flight checks: manifest validation, parse-check of all Public scripts, FunctionsToExport sync check, clean git tree enforcement, CHANGELOG presence check, and API key read from Windows Credential Manager

---

## [1.0.0] — 2026-04-01

### Added
- Initial release
- `toolkit` CLI dispatcher with numeric and named command lookup
- User lifecycle: `new-user`, `offboard-user`, `reset-password`, `set-userlicence`
- User reports: `get-userreport`, `get-allusers`, `get-mfaaudit`, `get-guestaudit`, `get-signinlogs`
- Tenant health: `get-tenantreport`
- Mailbox & Exchange: `get-userperms`, `get-mailboxperms`, `add-mailboxperms`, `set-forwarding`, `remove-forwarding`, `get-archive`, `enable-autoexpand`, `disable-autocalevents`, `check-mailflow`, `get-sharedmailboxaudit`
- Groups: `get-groupmembers`
- MFA & Auth: `get-smsmfa`, `set-smsmfa`, `add-smsmfa`, `add-tap`, `remove-taps`
- System: `inherit-permissions`, `kill-graph`
