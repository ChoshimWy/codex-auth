# macOS Status Bar App — Product Requirements

> **Release history**
>
> - **v1 (shipped, app 0.1.0)** — menu-bar status, account panel, list/refresh,
>   usage states, and account switching.
> - **v2 (this update, implemented 2026-08-13)** — account management inside the app: import
>   `auth.json` (standard, CLIProxyAPI, or purge recovery), alias set/rename/
>   clear, login through the Codex CLI device-auth flow, export, remove,
>   Codex App launching, and CLI environment installation/update (Section 13).
>   These features require non-breaking `--json` extensions to the
>   [JSON API](./json-api.md) first (Section 11). The app
>   remains a graphical client of the JSON contract and never reads or writes
>   `~/.codex` account storage directly.

## 1. Purpose

Build a native macOS menu-bar companion for `codex-auth` that lets users see
the active Codex account, inspect rate-limit usage, and switch accounts with a
small number of deliberate actions. The app is a graphical client of the
versioned JSON contract in [JSON API](./json-api.md); it is not an alternative
account store and must not parse the human-readable CLI output.

This v2 update extends the app from read-and-switch into full account
management: everything `codex-auth` can do to account storage through a
structured command should be doable from the app, while the CLI remains the
sole owner of accounts, auth files, persistence, and API communication.

The supplied design establishes the visual direction: translucent Liquid Glass
surfaces, prominent usage status, account avatars, and a compact menu-bar
presence. It is a product reference rather than a pixel-perfect implementation
specification.

## 2. Goals and Non-goals

### Goals

- Show the active account and its primary rate-limit status directly from the
  macOS menu bar.
- Open a compact account panel for active-account detail, other-account status,
  refresh, and account switching.
- Make stale, unavailable, refreshing, and zero-remaining states immediately
  understandable without hiding the account identity.
- Keep destructive actions deliberate and recover safely from uncertain CLI
  mutations.
- Respect the existing `codex-auth` JSON API compatibility and privacy
  boundaries.
- **v2** Add accounts from the app: import one or many auth files (standard or
  CLIProxyAPI format), recover with a purge import, or sign in through the
  Codex CLI device-auth flow.
- **v2** Name accounts from the app: set, rename, and clear aliases with the
  same validation rules the CLI enforces.
- **v2** Export stored account snapshots (standard or CPA) to a user-chosen
  folder for backup.
- **v2** Remove accounts and copy identifying details (email) from the app.
- **v2** Launch the Codex App with the same environment injection as
  `codex-auth app`.
- **v2** Give every mutation one consistent pipeline: capability check, JSON
  contract validation, uncertain-state locking, and structured error recovery.

### Non-goals for this update

- Reimplement authentication, registry editing, or API refresh inside the app.
- Parse table output, prompts, warnings, or errors emitted by the ordinary CLI.
- Provide seamless live switching inside the Codex App. Users must be told to
  restart affected Codex clients after a successful switch.
- Set a "default account". The CLI has no default-account concept; this stays
  deferred until the CLI gains one.
- Replicate the live TUI (`list --live`, interactive pickers, `config live`
  cadence). The app has its own refresh cadence; live-mode configuration is
  out of scope.
- Guarantee account usage is real-time; the displayed snapshot can originate
  from the API, local sessions, cache, or no data.

## 3. Users and Primary Jobs

| User | Job to be done | Success condition |
| --- | --- | --- |
| Multi-account individual | Know which account is active and how much 5-hour capacity remains | The menu-bar status answers this at a glance. |
| User nearing a limit | Find another usable account quickly | The panel ranks all stored accounts by clear status and provides a one-step switch. |
| Account administrator | Add, name, back up, and retire accounts without a terminal | Import, alias, export, login, and remove are all reachable from the app with visible results. |
| Privacy-conscious user | Inspect saved usage without making remote requests | The user can refresh via local-only mode and sees its data source. |
| Troubleshooting user | Understand why data or an action failed | The UI distinguishes CLI availability, refresh failure, no data, and uncertain mutation state. |

## 4. Information Architecture

### 4.1 Menu-bar item

The always-visible item contains:

- A status icon.
- The active account's primary `used_percent` when available; otherwise an
  unknown-state glyph.
- A semantic accessibility label with active account identity, remaining or
  used percentage, and current state.

The item opens the account panel on click. It must not expose an email address
in the compact label by default.

### 4.2 Account panel

The panel has three regions, matching the visual hierarchy in the design:

1. **Header** — app name, a Refresh control, an **Add account** menu (Login,
   Import auth file…, Import CPA…), a **Launch Codex App** control, and
   Settings/About entry point.
2. **Current account** — avatar/initial, alias or account name, email,
   normalized plan, active marker, headline percentage, rate-limit rows, credit
   information, refresh source, timestamp, and reset time.
3. **Other accounts** — compact rows for all non-active accounts, each showing
   identity, primary status, and a Switch action.

The footer shows the last successful synchronization time and number of stored
accounts. An empty state explains that no managed accounts are available and
directs the user to the in-app Login or Import actions (v1 pointed to the CLI;
v2 replaces that with in-app entry points).

### 4.3 Account detail card

Selecting an account opens a detail card or popover. It includes only data
provided by the account object: identity, plan, auth mode, creation and last
use timestamps, usage windows, credits, source, and reset times. The card
offers **Switch to this account**, and a destructive **Remove account** action.

### 4.4 Account context menu

The overflow/context menu is a progressive-disclosure surface. As of v2 it
contains:

- Switch to this account.
- Set alias / Rename alias / Clear alias.
- Copy email.
- Refresh usage.
- View details.
- Remove account, with confirmation.

Only "set default account" and per-account export remain deferred: the CLI has
no default-account concept, and `codex-auth export` is whole-registry, not
per-account. A deferred entry is implemented only when an equivalent JSON
command is documented.

### 4.5 Account management (Settings > Accounts)

A dedicated Accounts tab hosts the wider management surface:

- **Import** — pick an auth file or directory, optionally set an alias for a
  single file, choose standard or CPA mode; result summary (imported / updated
  / skipped with per-file reasons). Purge import lives under an "Advanced"
  disclosure with a strong warning.
- **Export** — pick a destination folder, choose standard or CPA format; shows
  exported and skipped counts and a Reveal in Finder action.
- **Login** — entry point into the same login flow as the header Add menu.
- **Launch Codex App** — advanced options for `--id`, `--codex-cli-path`, and
  `--codex-home` overrides used by the app command.

### 4.6 Login flow

Login follows `codex-auth login --device-auth`:

1. The app shows a sheet with the verification URL and user code, plus Copy
   code and Open browser actions.
2. The sheet tracks progress until the CLI completes the login and import, or
   fails; the user can cancel, which leaves the account list unchanged.
3. On success the app refreshes and announces the new active account.

If the device-auth flow cannot be driven structurally (see Section 14), the
app offers "Open in Terminal" as a fallback that runs `codex-auth login` in
Terminal.app and refreshes when the user returns.

### 4.7 Codex App launcher

The header Launch control runs `codex-auth app` and reports a distinct result:
launched, already running, or failed with a non-secret message. The advanced
options in Section 4.5 map to the `app` command flags.

## 5. Functional Requirements

### FR-1: Read account state

- On launch and when the panel opens, execute `codex-auth list --json` once.
- The app may offer a **Local-only refresh** that executes
  `codex-auth list --skip-api --json`; it must label the result as local/cache
  data as appropriate.
- Parse exactly one JSON document from stdout, validate `schema_version: 1`,
  and ignore unknown optional fields.
- Drain stderr for diagnostics, but never use stderr or a non-JSON message as
  business data.
- Prevent overlapping commands. While a command is in progress, disable
  conflicting Refresh, Switch, Remove, Alias, Import, Export, Login, and
  Launch controls and show a progress state.

### FR-2: Show usage accurately

- Render the primary window (`usage.primary`) as the headline status. The
  label must say whether the percentage is used or remaining; the two must not
  be conflated.
- Render the secondary window only when present.
- Display reset times as localized absolute time plus a concise relative form
  where available.
- Display `credits` only when `has_credits` is true. Respect `unlimited` and
  never infer credit availability merely because a credit object exists.
- Show `usage.source` (`api`, `local`, `cache`, or `none`) and `updated_at` in
  the detail-level UI. A cached snapshot remains visible after refresh failure
  but must carry a stale/failed indication.
- Do not display a fabricated percentage, reset time, or account metadata when
  a value is absent.

### FR-3: Status semantics and visual states

| State | Trigger | Menu-bar and panel behavior |
| --- | --- | --- |
| Normal | Primary usage is available and below warning threshold | Neutral status icon and blue/semantic accent. |
| Low capacity | Primary remaining capacity is below 20% | Warning icon and orange accent; preserve the exact percentage. |
| Exhausted | Remaining capacity is 0% | Critical icon and red accent; Switch stays available. |
| Refreshing | A read command is running | Progress indicator; retain the previous snapshot with a refreshing label. |
| CLI unavailable | Executable cannot be located or launched | Warning state, actionable path/configuration guidance, and disabled mutations. |
| No usage data | `usage.source` is `none` or primary usage is absent | Unknown glyph and explanatory text; identity remains visible. |
| Refresh error | `usage.refresh.status` is an error state | Show the cached/local snapshot, source, and non-secret error summary. |
| State uncertain | CLI returns `state_uncertain` after mutation began | Block further mutations and require a successful list refresh before retrying. |

The 20% low-capacity threshold is user-configurable in Settings. `0%` is
always critical regardless of that threshold. Color is supplemental: each
state also has an icon and accessible text.

### FR-4: Switch account

- A Switch control is available for every non-active account with a stable
  `account_key`.
- The app executes `codex-auth switch <account_key> --json`; it must not use
  the transient display `number` as the mutation identifier.
- Before dispatch, show a confirmation only when a user preference requires
  it; otherwise a single explicit action is sufficient.
- On success, replace UI state from `switched_to`, then run a serialized list
  refresh to reconcile all rows.
- Show a non-blocking notice that Codex CLI and Codex App may need restarting
  for the new account to take effect.
- Handle `account_not_found` and `ambiguous_query` as an action failure with a
  refresh option. Since the app passes `account_key`, ambiguity is unexpected
  and should be recorded for diagnostics.

### FR-5: Remove account

- The action is destructive, visually separated, and requires explicit
  confirmation showing the account alias/name and email.
- Execute `codex-auth remove <account_key> --json` only after confirmation.
- On success, refresh the list and announce the active-account change when
  `new_active_account_key` differs.
- If the response is `selector_resolution_failed`, show the result and make no
  local optimistic deletion. The CLI guarantees all-or-nothing resolution.
- If the response is `state_uncertain`, retain all current rows, block
  mutations, and require a completed list refresh before re-enabling them.

### FR-6: Refresh behavior and privacy

- The standard Refresh action uses API-backed `list --json`; it may contact the
  documented ChatGPT endpoints using the stored account token.
- The refresh UI must disclose this behavior before the first API-backed
  refresh and link to the project's API/privacy documentation.
- Local-only refresh uses `--skip-api` and must not claim that all accounts
  were freshly measured; local session data can lag.
- Refresh failures are non-destructive. Preserve the last valid snapshot and
  expose a retry affordance.

### FR-7: Settings

Settings includes:

- Configurable low-capacity threshold (default 20%).
- Toggle for confirmation before switching.
- Configurable path to the `codex-auth` executable, with validation and a
  **Reveal diagnostic** action; use PATH discovery by default.
- Toggle for launching with the menu-bar item only.
- Preferences for system appearance and reduced motion.
- **v2** Accounts tab as described in Section 4.5.
- **v2** CLI section: bundled and installed CLI versions, install/update
  action, install-target selection, and PATH guidance (Section 13).

Settings must not expose, copy, log, or export auth tokens.

### FR-8: Alias management (v2)

- Every account row exposes Set alias / Rename / Clear alias via the context
  menu and detail card.
- The alias editor pre-validates the CLI's rules client-side (non-empty, not
  all digits, no control characters) and surfaces the CLI's structured errors
  inline: `invalid_alias` and `duplicate_alias` (naming the conflicting
  account).
- Execute `codex-auth alias set <account_key> <alias> --json` or
  `codex-auth alias clear <account_key> --json`; pass `account_key`, never the
  display `number`.
- On success, refresh the list and update the menu-bar label, which renders
  the alias.

### FR-9: Import accounts (v2)

- The import panel accepts a single `.json` auth file or a directory of them
  via a native open panel. It offers Standard and CPA modes; CPA mode without
  a path scans `~/.cli-proxy-api/`.
- An optional alias field applies only to a single-file import and is disabled
  for directory imports (mirroring the CLI rule).
- Execute the matching `codex-auth import … --json` variant. The app passes
  only the picked path to the CLI and never opens or reads auth file contents
  itself.
- Render the per-file result list: `imported`, `updated`, or `skipped` with
  the reason (`InvalidJSON`, validation names such as `MissingEmail`, etc.).
  Show aggregate counts.
- Imported accounts do not become active; the app refreshes without changing
  the active row.
- Purge import lives behind an Advanced disclosure with a warning that it
  rebuilds the registry, resets stored usage, and re-derives the active
  account (from the current `auth.json`, else the first account). The app
  renders whatever `active_account_key` the response reports; a null value is
  only possible when no accounts remain, and that state must render correctly.

### FR-10: Export accounts (v2)

- The export panel picks a destination folder and offers Standard
  (`*.auth.json`) and CPA formats; CPA silently skips API-key accounts, so the
  panel must show the skipped count.
- Execute `codex-auth export [<dir>] [--cpa] --json` only after a consent
  dialog that states the exported files contain login credentials.
- Show exported and skipped counts, the destination, and a Reveal in Finder
  action.

### FR-11: Login (v2)

- The login sheet drives `codex-auth login --device-auth --json`: display the
  verification URL and user code, provide Copy code and Open browser actions,
  and show progress until the CLI reports completion or failure.
- The login-created account becomes active; the app refreshes and announces it.
  Login-created accounts have no alias (CLI behavior), so the app invites the
  user to set one afterwards.
- Cancellation or failure must leave the account list unchanged (the CLI's
  temporary `CODEX_HOME` isolation makes this the expected outcome; the app
  must not optimistically add rows).
- When the device-auth flow is unavailable, offer the documented
  "Open in Terminal" fallback running `codex-auth login` in Terminal.app, then
  refresh when the user returns.
- Never display tokens, access codes, or auth file contents in the flow.

### FR-12: Launch Codex App (v2)

- The header Launch control executes `codex-auth app --json` and reports
  `launched`, `already_running`, or a failure with a non-secret message.
- Advanced options in Settings > Accounts map to `--id`, `--codex-cli-path`,
  and `--codex-home` and persist as plain paths/identifiers only.

### FR-13: Mutation pipeline and capability gating (v2)

- All CLI interaction goes through one serialized JSON command runner (the v1
  code duplicated process handling in `MenuBarStore`; v2 unifies it).
- On first use per launch the app probes the installed CLI's capabilities via
  the structured version command (Section 11.7). If a required command is
  unsupported, the affected feature group is disabled with guidance showing
  the required `codex-auth` version. The app must never downgrade to parsing
  human-readable output.
- `state_uncertain` locks every mutation surface (switch, remove, alias,
  import, purge), not just switch; a successful `list --json` unlocks.

## 6. UI and Interaction Requirements

- Use macOS-native controls, keyboard navigation, VoiceOver labels, Dynamic
  Type-compatible text sizing, and high-contrast-safe semantic colors.
- Support light and dark appearance. The Liquid Glass effect is decorative;
  every surface needs a readable opaque/high-contrast fallback.
- Use 16 pt corner radii for prominent cards and 12 pt for compact rows as a
  starting visual token, not a fixed accessibility constraint.
- Account avatars use initials and a deterministic non-sensitive color; do not
  derive imagery from private account data.
- The panel should be usable without horizontal scrolling at standard macOS
  text sizes. Other-account rows may scroll vertically.
- All user-visible GUI copy is localized. English is the required initial
  locale; the supplied Chinese copy is a design-reference localization. All
  v2 strings (import/export/login/alias/launcher surfaces) ship in both
  locales.
- Import, export, and login use native file dialogs and sheets; each shows a
  clear progress state and a dismissible result summary. Privacy disclosures
  (API refresh, export consent, login data collection) are shown before the
  corresponding action first runs.

## 7. Data, Security, and Compatibility Boundaries

- The CLI remains the sole owner of accounts, auth files, persistence, plan
  normalization, and API communication.
- Use only the commands and fields in [JSON API](./json-api.md). No direct
  reads or writes to `~/.codex` account storage are permitted — including for
  the v2 import and export features: the app passes user-picked paths to the
  CLI and never reads auth file contents.
- `account_key` is stable for mutations; `number` is display-only and changes
  with list ordering.
- Treat unknown JSON enum values and error codes as generic, readable fallback
  states; do not reject otherwise compatible schema-1 documents.
- Do not log email addresses, account keys, command stdout, stderr, or any
  token-bearing data by default. Diagnostic export, if later added, must be
  redacted and explicitly confirmed.
- Export destinations receive credential-bearing files: the app must obtain
  explicit consent with a disclosure before executing an export.
- If `--json` is unsupported by the installed executable, fail closed: explain
  the required `codex-auth` capability and disable account operations. Do not
  downgrade to parsing human-readable output.
- The v2 features require non-breaking `--json` additions (Section 11). The
  registry's on-disk schema (currently 4) is unrelated and unchanged: alias
  and live-interval storage already exist there, so no registry migration is
  part of this update.
- CLI installation writes outside the app bundle only to a user-chosen
  `codex-auth` file in a PATH directory, atomically, after explicit consent;
  admin escalation is requested once per install, and no other file is
  modified or removed.

## 8. Error Handling and Recovery

| Condition | Required recovery |
| --- | --- |
| CLI missing, not executable, or exits with usage error | Show setup guidance and retain no stale mutation controls. |
| Invalid JSON, multiple documents, unsupported schema version | Stop processing, show a compatibility error, and preserve the last valid read-only snapshot only if clearly marked stale. |
| Structured handled error | Show its human-readable message without exposing sensitive payload fields; offer Retry/List as relevant. |
| Network/API refresh error | Keep existing snapshot, label it stale, and offer local-only or normal retry. |
| Mutation result uncertain | Do not infer success or failure; lock mutation controls until `list --json` succeeds. |
| `invalid_alias` / `duplicate_alias` | Inline editor error; for duplicates, name the conflicting account and keep the entered text for editing. |
| Per-file import failure (`InvalidJSON`, validation names) | Shown as a result row with its reason; successful files in the same import still apply and the list refreshes. |
| Import/export path unreadable or not writable | Path-specific guidance and a Retry action that reopens the picker. |
| Login failed or cancelled | Restore prior state from a fresh list; no optimistic rows; expose retry and the Terminal fallback. |
| `app_launch_failed` | Non-secret error message; advanced options remain editable. |
| Purge completed with empty or no-active registry | Render the empty/no-active state with Login and Import entry points; never claim data loss silently. |
| Required JSON command unsupported by installed CLI | Disable the feature group; show the required `codex-auth` version in Settings. |
| App relaunch | Start from a fresh CLI list; do not persist account/auth state as an alternate source of truth. |

## 9. Release Scope and Acceptance Criteria

### Phased delivery plan

| Phase | Scope | Docs and tests |
| --- | --- | --- |
| **P0 — CLI JSON extensions** (prerequisite) ✅ | Non-breaking schema-1 `--json` support for `alias set/clear`, `import` (standard/CPA/purge), `export`, `login --device-auth`, `app`, and a structured version/capability command (Section 11). Device-auth output-capture spike (Section 14). | Update `docs/json-api.md` and `docs/commands/*.md`; Zig tests for each new command in `tests/`. |
| **P1 — App mutation foundation** ✅ | Unify `CLIProcessService` into one serialized JSON runner (replacing the duplicated process logic in `MenuBarStore`); capability probe and fail-closed gating; `schema_version` validation; `state_uncertain` locking for all mutations; implement Remove and Copy Email; close v1 gaps (restart notice after switch, local-only refresh, first-refresh privacy disclosure, Codex Auth Path setting). | Swift unit tests with JSON fixtures and a fake CLI process for mapping, validation, and pipeline behavior. |
| **P2 — Account management UI** ✅ | Alias editor sheet; import panel (file/directory picker, alias field, Standard/CPA, purge under Advanced); export panel with consent; Settings > Accounts tab; empty-state entry points to Login/Import. | UI smoke via manual checklist; localized en + zh strings for every new surface. |
| **P3 — Login, app launcher, CLI install** ✅ | Device-auth login sheet (URL/code, Copy, Open browser, progress, cancel) with the Terminal fallback; Launch Codex App control and status; advanced `app` options in Settings; CLI install/update wizard on first launch and after app updates, plus Settings > CLI (Section 13), with `package.sh` version stamping. | Manual end-to-end login checklist; unit tests for the login state machine and the install/update flow (fake filesystem and CLI). |
| **P4 — Optional and future** ✅ (switch --previous / clean / config JSON + UI, network-aware background refresh, threshold notifications) | Optional CLI/UI pairs: `switch --previous --json`, `clean --json`, `config get --json`; background refresh policy, threshold notifications, global shortcut, and richer themes from Section 10. | — |

Release notes: app version bumps to 0.2.0 alongside the CLI release that
carries the new JSON commands. The app fails closed on older CLIs via the
capability probe, so app and CLI do not need lock-step releases.

### MVP scope (v1, shipped)

The v1 MVP includes menu-bar status, account panel, list/refresh, usage status
states, account details, and switching. Removal, alias, import, export, login,
and launch ship in v2 per the phases above; each mutation ships only after its
confirmation and uncertain-state flow are covered by tests.

### Acceptance criteria

1. Given a valid `list --json` response, the menu bar and panel show the
   active account and correctly distinguish primary and secondary usage.
2. Given cached data plus an API refresh failure, the last snapshot remains
   visible and is labelled as stale/error rather than current API data.
3. Given remaining capacity below the configured threshold or exactly zero,
   the correct warning/critical state is communicated without relying on color
   alone.
4. Switching and removal invoke structured commands with `account_key`, never
   the list row number.
5. A `state_uncertain` response prevents further mutations until a successful
   list operation completes.
6. An installed CLI without recognized `--json` support disables operations
   and never attempts to parse ordinary CLI output.
7. VoiceOver can identify every account row, its active state, usage state,
   and action controls; the interface remains usable in light, dark,
   high-contrast, and increased-text-size configurations.
8. API-backed refresh presents its privacy disclosure before first use, and
   local-only refresh is visibly identified as potentially delayed data.
9. Given a picked auth file or directory in Standard or CPA mode, the import
   panel shows per-file imported/updated/skipped results with reasons and then
   refreshes; no token content is ever displayed or logged.
10. Alias set, rename, and clear round-trip through `alias --json`; invalid
    and duplicate aliases render as actionable inline errors.
11. Export runs only after consent, writes to the chosen folder, reports
    exported and skipped counts, and offers Reveal in Finder.
12. Device-auth login (or the documented Terminal fallback) ends with the new
    account visible and active; a cancelled or failed login leaves the account
    list unchanged.
13. Remove requires confirmation showing alias/email, and the uncertain-state
    lock applies to remove, alias, import, and purge exactly as to switch.
14. The app probes the installed CLI at launch and disables feature groups
    whose structured commands are unsupported, showing the required
    `codex-auth` version.
15. After a purge import that clears the active pointer, the app renders the
    no-active-account state without error and offers Login/Import entry
    points.
16. The Launch Codex App control reports launched / already running / failed
    distinctly, and never exposes injected environment values beyond plain
    paths and identifiers.
17. On first launch with no local CLI, the wizard installs the bundled binary
    into a PATH directory atomically, verifies it via the capability probe,
    and `codex-auth` works from a terminal afterwards.
18. When a local CLI exists (older, equal, or newer), the update action
    replaces it with the bundled version; replacing a newer local version
    requires explicit confirmation showing both versions.
19. The app remains fully functional without any local CLI (bundled
    fallback); the wizard is skippable and never writes outside the chosen
    target file.

## 10. Future Enhancements

- Quick actions and global keyboard shortcut.
- A richer visual theme system, provided it preserves native accessibility and
  readability requirements.
- A default-account concept, pending the corresponding CLI feature.

## 11. Required CLI JSON API Extensions (prerequisite)

All additions are non-breaking under `schema_version: 1`: new commands, new
success/error documents, and new error codes are additive. The authoritative
spec updates go into [json-api.md](./json-api.md); the sketches below state the
contract the app is planned against. No registry on-disk schema bump is
required.

Exit-code semantics are unchanged: `0` success, `1` handled error with a JSON
error document, `2` usage error. Interactive fallbacks (pickers, TTY
confirmation) never apply in `--json` mode.

### 11.1 `alias --json`

```shell
codex-auth alias set <account_key> <alias> --json
codex-auth alias clear <account_key> --json
```

```json
{
  "schema_version": 1,
  "command": "alias",
  "operation": "set",
  "updated": { "number": 1, "account_key": "…", "email": "…", "alias": "work" }
}
```

New error codes: `invalid_alias` (empty, all-digit, or control characters) and
`duplicate_alias` (case-insensitive collision; message names the conflicting
account). `account_not_found` is reused for an unknown key.

### 11.2 `import --json`

```shell
codex-auth import <path> [--alias <alias>] --json
codex-auth import --cpa [<path>] --json
codex-auth import --purge [<path>] --json
```

```json
{
  "schema_version": 1,
  "command": "import",
  "mode": "standard",
  "source": "/Users/a/token.json",
  "results": [
    { "path": "token.json", "status": "imported", "email": "a@example.com", "reason": null },
    { "path": "broken.json", "status": "skipped", "email": null, "reason": "MissingEmail" }
  ],
  "imported_count": 1,
  "updated_count": 0,
  "skipped_count": 1,
  "active_account_key": null,
  "registry_rebuilt": true
}
```

`--alias` is valid only for a single-file import; JSON mode mirrors the human
CLI's warn-and-ignore behavior for the other modes (the app disables the
alias field for directory imports client-side). `reason` values reuse the
human CLI's existing per-file labels (`InvalidJSON`, `MissingEmail`, …); the
`email` field is present only when the engine records it. `registry_rebuilt`
appears only for purge success, which may report a null `active_account_key`
(only when no accounts remain). Per-file failures are result rows, not
command-level errors; path-level problems are a handled `path_unreadable`
error.

### 11.3 `export --json`

```shell
codex-auth export [<dir>] [--cpa] --json
```

```json
{
  "schema_version": 1,
  "command": "export",
  "format": "standard",
  "destination": "/Users/a/backup",
  "exported_count": 2,
  "skipped_count": 1
}
```

`destination` is the resolved export directory (the default backup directory
when the path is omitted). `skipped_count` covers CPA-mode API-key accounts.
A non-writable destination is a handled `path_not_writable` error. The app
reveals the destination directory in Finder rather than receiving a file
list.

### 11.4 `login --device-auth --json`

A two-phase document flow: the process stays alive between the phases while
the user completes the browser flow, and every phase document exits `0`.
The P0 spike confirmed codex 0.147.0 prints the device URL and user code to
stdout (with ANSI color); the CLI captures them with ANSI-tolerant parsing.

Phase 1, while waiting for the user:

```json
{
  "schema_version": 1,
  "command": "login",
  "mode": "device_auth",
  "phase": "awaiting_user",
  "verification_url": "https://…",
  "user_code": "XXXX-XXXX"
}
```

Phase 2, after the child completes and the account is imported and activated:

```json
{
  "schema_version": 1,
  "command": "login",
  "mode": "device_auth",
  "phase": "completed",
  "active_account_key": "…",
  "account": { "…": "full account object" }
}
```

Failure phases use `"phase": "failed"` with a non-secret `message` and still
exit `0`; errors before the first phase document use the standard error
documents. The CLI keeps the temporary `CODEX_HOME` isolation, so a failed or
killed login never mutates the real registry. Killing the CLI mid-flow cannot
emit a document and may leave the temporary home behind; the app cleans it
up on its next login attempt.

### 11.5 `app --json`

```shell
codex-auth app [--id <bundle-id>] [--codex-cli-path <path>] [--codex-home <path>] --json
```

```json
{
  "schema_version": 1,
  "command": "app",
  "status": "launched",
  "app_id": "com.openai.codex",
  "codex_cli_path": null
}
```

`status` is `launched` or `already_running`; `codex_cli_path` is null when
none was resolved (including the already-running case). Human diagnostics
still go to stderr; launch failures are handled `app_launch_failed` errors.

### 11.6 Registry and contract invariants

- Registry on-disk schema stays 4: alias and `interval_seconds` already
  persist there, and import/export/launch change nothing in the persisted
  shape.
- Account objects, plan normalization, and `usage.*` semantics are unchanged;
  the GUI keeps ignoring unknown fields and using generic fallbacks for
  unknown codes and enums.

### 11.7 Version and capability probe

```shell
codex-auth --version --json
```

```json
{
  "schema_version": 1,
  "command": "version",
  "version": "0.3.0-alpha.10",
  "json_api_schema": 1,
  "supported_commands": ["list", "switch", "remove", "alias", "import", "export", "login", "app"]
}
```

The app gates feature groups on `supported_commands` and fails closed when a
required entry is absent (exact flag form is finalized in the CLI work).

## 12. Command Coverage Matrix

| CLI command | App surface | Phase | Notes |
| --- | --- | --- | --- |
| `list --json` | Menu bar, panel, refresh | v1 (shipped) | — |
| `list --skip-api --json` | Local-only refresh | ✅ | v1 gap closure |
| `switch <key> --json` | Rows, detail card | v1 (shipped) | P1 adds restart notice |
| `remove <key> --json` | Context menu, confirmation | ✅ | v1 FR-5, first implemented in v2 |
| `alias set/clear --json` | Context menu alias sheet | ✅ | — |
| `import [--cpa] [--purge] --json` | Header Add menu, Settings > Accounts | ✅ | Purge under Advanced |
| `export [--cpa] --json` | Settings > Accounts | ✅ | Consent before execution |
| `login --device-auth --json` | Header Add menu, login sheet | ✅ | Terminal fallback |
| `app --json` | Header menu launch item | ✅ | — |
| `--version --json` | Launch-time capability probe | ✅ | Fail-closed gate |
| `config live --interval <s> --json` / `config get --json` | Settings > Accounts maintenance | ✅ | Live TUI interval |
| `clean [background] --json` | Settings > Accounts maintenance | ✅ | Backup/stale cleanup |
| `switch --previous --json` | Header menu | ✅ | — |
| Interactive pickers, `--live` | — | Out of scope | TTY-only surfaces |

`list --active --json` already exists and needs no dedicated UI (the active
row covers it). `remove --all --json` exists but is intentionally not exposed
in the v2 UI: removing the whole registry deserves no single-click surface.
Installing/updating the local `codex-auth` binary itself is not a JSON API
command: it is the first-launch wizard and Settings > CLI concern in
Section 13 ✅.

## 13. CLI Bundling, Installation, and Updates

### 13.1 Baseline: the CLI already ships inside the app

`Scripts/package.sh` builds `codex-auth` from this repository at package time
(`zig build -Doptimize=ReleaseFast`), copies it into the app bundle at
`Contents/Resources/CodexSwitcher_CodexSwitcher.bundle/codex-auth`, signs it
with the app, and ships it inside the notarized DMG. Runtime resolution
prefers this bundled CLI, then `which codex-auth`, then `/opt/homebrew/bin`
and `/usr/local/bin`, so the app already works with no CLI environment at
all. What this update adds is the other direction: installing the bundled CLI
into the user's terminal environment and keeping it in lockstep with the app.

### 13.2 Goals

- Install the bundled `codex-auth` into a directory on the default PATH so a
  terminal has `codex-auth` available immediately after installing the app.
- Keep the local CLI in lockstep with the app: after installation and after
  every app update, the installed copy equals the bundled version — unless
  the user skips the wizard. The chosen policy is **always overwrite with the
  bundled version**; a newer local version is replaced too, but only after an
  explicit confirmation that shows both versions.
- Make the app itself independent of this: the bundled CLI remains the
  default execution path, so a missing or stale local CLI never breaks the
  app.

### 13.3 Install wizard (first launch and after updates)

- On first launch, and on first launch after an app update whose bundled CLI
  version differs from the last installed one (tracked in UserDefaults), the
  app shows an **Install / Update Command Line Tool** wizard. Skipping records
  the bundled version as seen, so the wizard appears once per version and
  does not nag at every login; at login-time startup the offer is deferred to
  the first time the user opens the panel instead of blocking modally.
- The wizard displays the bundled version, the detected local version and
  path (or "not installed"), and the selected install target. The user can
  skip; the app keeps working from the bundled CLI.
- Install writes the bundled binary atomically (temp file in the target
  directory, `chmod +x`, rename over `codex-auth`), preserving its code
  signature (the notarization ticket does not transfer, which is irrelevant
  for terminal use), and then verifies the result by running the installed
  binary's capability probe (`--version --json`, Section 11.7).
- If the detected local version is newer than the bundled one, the wizard
  shows both versions and requires an explicit confirmation before replacing.
- Never writes or removes any file other than `codex-auth` in the target
  directory.

### 13.4 Install target selection

In order:

1. `/opt/homebrew/bin` — Apple Silicon Homebrew, on the default PATH, usually
   user-writable when Homebrew exists.
2. `/usr/local/bin` — Intel Homebrew or a common user-writable location, also
   on the default PATH.
3. `~/.local/bin` — never requires admin, but is not on the default PATH; the
   wizard then offers PATH guidance (a copyable shell line and instructions;
   the app does not edit shell profiles by default).

- Candidates that exist and are writable are used without elevation. If no
  candidate is writable, the wizard requests a single explicit admin
  authorization (osascript/Authorization Services) and installs into the
  PATH directory that exists, creating a missing directory root-owned when
  necessary.
- If the detected local copy was installed by npm (resolve the `which`
  symlink first; the real path then sits inside a global `node_modules`), the
  wizard proceeds with the same overwrite policy but notes that a later
  `npm update -g` may replace it again.
- The selected target is remembered and shown in Settings > CLI with a Change
  option.

### 13.5 Settings > CLI

- Shows the bundled CLI version, the installed version and path, and whether
  the install location is on the default PATH.
- Install / Update and Change target actions; the Codex Auth Path pin
  (FR-7, planned in P1) still overrides runtime resolution when set.

### 13.6 Update semantics

- The local CLI is only ever written by the wizard, never silently in the
  background. App updates trigger the resync offer on the next launch.
- The app's own execution path continues to prefer the bundled CLI, so
  version skew between the app and the local CLI cannot break the app.

### 13.7 Packaging changes

- `Scripts/package.sh` stamps the bundled CLI version into the app bundle
  (Info.plist key or a version resource) so the wizard can compare versions
  without executing anything. The app version and DMG filename (currently
  hardcoded `0.1.0` in `Scripts/Info.plist` and the DMG name) are
  parameterized in the same pass so the 0.2.0 release names itself correctly.
- DMG layout, signing, and notarization are unchanged; no pkg pipeline is
  added. The current build is arm64-only (the scripts use the
  `arm64-apple-macosx` release path); universal builds remain out of scope.

## 14. Open Questions

1. **Device-auth capture.** Resolved in P0: the spike confirmed codex 0.147.0
   prints the device URL and user code to stdout; the CLI captures them with
   ANSI-tolerant parsing. The Terminal fallback remains available in the app
   for the interactive login flow.
2. **Optional JSON extensions.** Should `switch --previous --json`,
   `clean --json`, and `config get --json` land in P0 or wait for demand?
   Proposal: defer to P4.
3. **Release coupling.** Ship the new JSON commands in the same CLI release as
   app 0.2.0 (proposal: yes — the capability probe makes the app safely
   compatible with older CLIs either way).
4. **PATH profile editing.** When the install target falls back to
   `~/.local/bin` (not on the default PATH), should the wizard offer to append
   the PATH line to the user's shell profile, or only show instructions?
   Proposal: instructions only.
5. **npm-owned copies.** Accept overwrite-by-default with a notice (proposal),
   or skip npm-owned targets and pick the next candidate directory?
