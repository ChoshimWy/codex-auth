# macOS Status Bar App — Product Requirements

## 1. Purpose

Build a native macOS menu-bar companion for `codex-auth` that lets users see
the active Codex account, inspect rate-limit usage, and switch accounts with a
small number of deliberate actions. The app is a graphical client of the
versioned JSON contract in [JSON API](./json-api.md); it is not an alternative
account store and must not parse the human-readable CLI output.

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

### Non-goals for the first release

- Reimplement authentication, registry editing, or API refresh inside the app.
- Parse table output, prompts, warnings, or errors emitted by the ordinary CLI.
- Provide seamless live switching inside the Codex App. Users must be told to
  restart affected Codex clients after a successful switch.
- Implement login, import, export, alias editing, default-account assignment,
  or launch-time Codex App injection until corresponding structured CLI
  commands exist.
- Guarantee account usage is real-time; the displayed snapshot can originate
  from the API, local sessions, cache, or no data.

## 3. Users and Primary Jobs

| User | Job to be done | Success condition |
| --- | --- | --- |
| Multi-account individual | Know which account is active and how much 5-hour capacity remains | The menu-bar status answers this at a glance. |
| User nearing a limit | Find another usable account quickly | The panel ranks all stored accounts by clear status and provides a one-step switch. |
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

1. **Header** — app name, a Refresh control, and Settings/About entry point.
2. **Current account** — avatar/initial, alias or account name, email,
   normalized plan, active marker, headline percentage, rate-limit rows, credit
   information, refresh source, timestamp, and reset time.
3. **Other accounts** — compact rows for all non-active accounts, each showing
   identity, primary status, and a Switch action.

The footer shows the last successful synchronization time and number of stored
accounts. An empty state explains that no managed accounts are available and
directs the user to the existing CLI workflow for adding one.

### 4.3 Account detail card

Selecting an account opens a detail card or popover. It includes only data
provided by the account object: identity, plan, auth mode, creation and last
use timestamps, usage windows, credits, source, and reset times. The card
offers **Switch to this account**, and a destructive **Remove account** action
when that structured capability is available.

### 4.4 Account context menu

The overflow/context menu is a progressive-disclosure surface. Its first
release may contain only actions backed by the JSON API:

- Switch to this account.
- Refresh usage.
- View details.
- Remove account, with confirmation.

The following design-reference entries are explicitly deferred rather than
implemented via text-output parsing: set default account, edit alias, copy
email, and export account. They may be enabled only when an equivalent JSON
command is documented.

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
  conflicting Refresh, Switch, and Remove controls and show a progress state.

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

Settings must not expose, copy, log, or export auth tokens.

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
  locale; the supplied Chinese copy is a design-reference localization.

## 7. Data, Security, and Compatibility Boundaries

- The CLI remains the sole owner of accounts, auth files, persistence, plan
  normalization, and API communication.
- Use only the commands and fields in [JSON API](./json-api.md). No direct
  reads or writes to `~/.codex` account storage are permitted.
- `account_key` is stable for mutations; `number` is display-only and changes
  with list ordering.
- Treat unknown JSON enum values and error codes as generic, readable fallback
  states; do not reject otherwise compatible schema-1 documents.
- Do not log email addresses, account keys, command stdout, stderr, or any
  token-bearing data by default. Diagnostic export, if later added, must be
  redacted and explicitly confirmed.
- If `--json` is unsupported by the installed executable, fail closed: explain
  the required `codex-auth` capability and disable account operations. Do not
  downgrade to parsing human-readable output.

## 8. Error Handling and Recovery

| Condition | Required recovery |
| --- | --- |
| CLI missing, not executable, or exits with usage error | Show setup guidance and retain no stale mutation controls. |
| Invalid JSON, multiple documents, unsupported schema version | Stop processing, show a compatibility error, and preserve the last valid read-only snapshot only if clearly marked stale. |
| Structured handled error | Show its human-readable message without exposing sensitive payload fields; offer Retry/List as relevant. |
| Network/API refresh error | Keep existing snapshot, label it stale, and offer local-only or normal retry. |
| Mutation result uncertain | Do not infer success or failure; lock mutation controls until `list --json` succeeds. |
| App relaunch | Start from a fresh CLI list; do not persist account/auth state as an alternate source of truth. |

## 9. Release Scope and Acceptance Criteria

### MVP scope

The MVP includes menu-bar status, account panel, list/refresh, usage status
states, account details, switching, and the full structured-error/recovery
behavior above. Removal ships only after its confirmation and uncertain-state
flow are covered by tests.

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

## 10. Future Enhancements

- Background refresh with user-controlled cadence and power/network policy.
- Notification when capacity crosses a configured threshold.
- Quick actions and global keyboard shortcut.
- Structured CLI support for alias management, import/export, login, and
  default-account preferences.
- A richer visual theme system, provided it preserves native accessibility and
  readability requirements.
