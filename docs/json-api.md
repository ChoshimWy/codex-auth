# JSON API

`codex-auth` provides a versioned JSON contract for its same-version GUI and
for automation callers. The GUI invokes commands serially, reads exactly one
JSON document from stdout, and drains stderr without using warning text for
program logic.

## Compatibility

Every document contains `"schema_version": 1`. Clients must ignore unknown
object fields and use generic fallbacks for unknown error codes and enum
values. Adding optional fields, error codes, or enum values is non-breaking in
schema 1. Removing or renaming fields, changing field types or existing value
semantics, making optional data required, or changing exit-code behavior is
breaking and requires a schema-version increment.

Stdout contains exactly one JSON document followed by a newline. The one
exception is `login --device-auth --json` (see below), which emits one
document per phase, sequentially on the same stream. Diagnostics and warnings
use stderr and are not part of the JSON contract.

| Exit code | Meaning |
|-----------|---------|
| `0` | Success |
| `1` | Handled operation error; stdout contains a JSON error document |
| `2` | Invalid command usage; stdout contains a JSON usage error when `--json` was recognized |

## Supported Commands

```shell
codex-auth list [--api|--skip-api] [--active] --json
codex-auth switch <query> --json
codex-auth remove <selector> [<selector>...] --json
codex-auth remove --all --json
codex-auth alias set <query> <alias> --json
codex-auth alias clear <query> --json
codex-auth import <path> [--alias <alias>] --json
codex-auth import --cpa [<path>] --json
codex-auth import --purge [<path>] --json
codex-auth export [<dir>] [--cpa] --json
codex-auth app [--id <id>] [--codex-cli-path <path>] [--codex-home <path>] --json
codex-auth login --device-auth --json
codex-auth switch --previous --json
codex-auth clean [background] --json
codex-auth config live --interval <seconds> --json
codex-auth config get --json
codex-auth --version --json
```

Interactive and live paths are not supported. `switch -` remains a human CLI
shortcut and is rejected when combined with `--json`; use
`switch --previous --json` instead. JSON-mode alias resolution never falls
back to the interactive picker: an ambiguous query is an `ambiguous_query`
error with `candidates`.

## Account Objects

```json
{
  "number": 1,
  "account_key": "user-abc::account-123",
  "email": "a@example.com",
  "alias": "work",
  "account_name": null,
  "plan": "business",
  "auth_mode": "chatgpt",
  "active": true,
  "created_at": 1730000000,
  "last_used_at": 1730001000,
  "usage": {
    "source": "cache",
    "updated_at": 1730002000,
    "primary": {
      "used_percent": 12.5,
      "window_minutes": 300,
      "resets_at": 1730010000
    },
    "secondary": null,
    "credits": {
      "has_credits": false,
      "unlimited": false,
      "balance": null
    },
    "reset_credits": null,
    "refresh": {
      "requested": true,
      "method": "api",
      "status": "http_error",
      "http_status": 503,
      "error_code": null
    }
  }
}
```

`account_key` is stable and should be used for switch/remove calls. `number` is
an ephemeral display selector valid only for the ordering returned by the
current invocation. Empty aliases and account names are `null`.

`plan` is already normalized by the CLI. Important mappings are:

| Input observed by the CLI | JSON plan |
|---------------------------|-----------|
| `team`, `self_serve_business_usage_based` | `business` |
| `business`, `enterprise_cbp_usage_based`, `enterprise`, `hc` | `enterprise` |
| `education`, `edu` | `edu` |

The GUI must not repeat this mapping. When both auth and stored usage provide a
plan, the usage plan wins.

### Usage

`usage.source` describes the displayed snapshot:

| Source | Meaning |
|--------|---------|
| `api` | Confirmed by an API response in this invocation |
| `local` | Read from a local Codex session in this invocation |
| `cache` | Loaded from the registry; a refresh was not requested or did not replace it |
| `none` | No displayable snapshot is available |

Snapshot fields remain present after refresh failure. `updated_at` is the
stored snapshot update timestamp and may remain unchanged after an equal
successful response.

`usage.refresh` describes only the current invocation:

| Field | Values |
|-------|--------|
| `requested` | Boolean |
| `method` | `api`, `local`, or `null` |
| `status` | `not_requested`, `ok`, `no_data`, `http_error`, `missing_auth`, `error` |
| `http_status` | HTTP status or `null` |
| `error_code` | Structured API/internal error name or `null` |

The credits object retains `has_credits`; callers must not infer it from object
presence or balance.

## Success Documents

### List

```json
{
  "schema_version": 1,
  "command": "list",
  "active_account_key": "user-abc::account-123",
  "accounts": []
}
```

### Switch

```json
{
  "schema_version": 1,
  "command": "switch",
  "switched_to": {}
}
```

### Remove

```json
{
  "schema_version": 1,
  "command": "remove",
  "removed": [],
  "new_active_account_key": null
}
```

### Alias

```json
{
  "schema_version": 1,
  "command": "alias",
  "operation": "set",
  "updated": {}
}
```

`operation` is `set` or `clear`. `updated` is the complete account object after
the change; after `clear` the account's `alias` is `null`. Alias commands
resolve the query from stored local data only, using the same selector rules
as the human command, and apply the same validation rules. `--json` may appear
anywhere after the `alias set`/`alias clear` subcommand.

### Import

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

`mode` is `standard`, `cpa`, or `purge`. `source` is the resolved import
source or `null`; it is `~/.cli-proxy-api` when CPA import omits the path and
`~/.codex/accounts` when purge omits the path. Each `results` row corresponds
to one imported file event: `path` is the file display label, `status` is
`imported`, `updated`, or `skipped`, `email` is present only when the engine
records it (multi-item files), and `reason` reuses the human CLI's per-file
labels (`InvalidJSON`, `MissingEmail`, …). `registry_rebuilt` appears only for
purge success. Per-file failures are result rows for multi-file scans; a
single-file import that fails validation escalates to a command-level
`registry_error` (engine behavior shared with the human CLI). Path-level
problems are a handled `path_unreadable` error. Imported accounts do not
become active, and `active_account_key` reflects the registry after the
import; clients should run `list --json` afterwards to reconcile rows.

### Export

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

`format` is `standard` or `cpa`. `destination` is the resolved export
directory (the default backup directory when the path is omitted).
`skipped_count` covers CPA-mode API-key accounts, which are skipped because
CPA format requires ChatGPT tokens. A destination that cannot be written is a
handled `path_not_writable` error.

### Version

```json
{
  "schema_version": 1,
  "command": "version",
  "version": "0.3.0-alpha.10",
  "json_api_schema": 1,
  "supported_commands": ["list", "switch", "remove", "alias", "import", "export", "app", "login", "clean", "config"]
}
```

`version` is the CLI release version. `supported_commands` lists the commands
that accept `--json` in this binary. Clients must gate features on this list
and fail closed when a required entry is absent.

### Switch (previous)

`switch --previous --json` switches back to `previous_active_account_key` and
reports the same success document as `switch <query> --json` (`switched_to`).
New error codes: `no_previous_account` (no previous key recorded, or it is
already active) and `previous_account_unavailable` (the recorded key no
longer exists).

### Clean

```json
{
  "schema_version": 1,
  "command": "clean",
  "target": "accounts",
  "auth_backups_removed": 1,
  "registry_backups_removed": 2,
  "stale_snapshot_files_removed": 0,
  "platform": null,
  "files_removed": null
}
```

`target` is `accounts` (backup and stale-file cleanup) or `background`
(legacy background registrations; then `platform` and `files_removed` are
set and the accounts counters are null).

### Config

```json
{
  "schema_version": 1,
  "command": "config",
  "section": "live",
  "interval_seconds": 120
}
```

`config get --json` reads the current configuration; `config live --interval
<seconds> --json` writes the live TUI refresh interval (5–3600) and reports
the stored value. `config get` requires `--json`.

### App

```json
{
  "schema_version": 1,
  "command": "app",
  "status": "launched",
  "app_id": "com.openai.codex",
  "codex_cli_path": null
}
```

`status` is `launched` or `already_running`. `app_id` is the resolved bundle
identifier (or package/AUMID on Windows); `codex_cli_path` is the CLI path
injected for the launch, or `null` when none was resolved (including the
already-running case). Human diagnostics (launch plan, download progress)
still go to stderr; stdout carries exactly this document. Launch failures are
a handled `app_launch_failed` error.

### Login (device auth)

`login --device-auth --json` drives the `codex login --device-auth` child with
piped stdout. It emits one document per phase, sequentially on stdout; the
process stays alive between phases while the user completes the browser flow.
Every phase document exits `0`; errors before any phase document is emitted
use the standard error-document/exit-code rules. Errors after the
`awaiting_user` document (such as a `state_uncertain` persistence failure
during the import step) emit a standard error document and exit `1`; clients
must treat any standard error document or a terminal phase document
(`completed`/`failed`) as the end of the stream.

Phase 1, as soon as the child prints the device URL and user code:

```json
{
  "schema_version": 1,
  "command": "login",
  "mode": "device_auth",
  "phase": "awaiting_user",
  "verification_url": "https://auth.openai.com/codex/device",
  "user_code": "XXXX-XXXX"
}
```

Phase 2, after the child succeeds and the account is imported and activated:

```json
{
  "schema_version": 1,
  "command": "login",
  "mode": "device_auth",
  "phase": "completed",
  "active_account_key": "…",
  "account": {}
}
```

A failed login still exits `0` and ends the stream with:

```json
{
  "schema_version": 1,
  "command": "login",
  "mode": "device_auth",
  "phase": "failed",
  "message": "codex login failed with exit code 1"
}
```

The CLI captures the URL and code from the child's stdout with ANSI-tolerant
parsing (confirmed against codex 0.147.0; a `https://auth.openai.com/…` line
plus a `XXXX-XXXX` shaped code line). The login runs against a temporary
`CODEX_HOME`, so a failed or killed login leaves the real registry untouched;
killing the CLI mid-flow cannot emit a document and may leave the temporary
home behind until the app cleans it up. `login --json` requires
`--device-auth`; the interactive flow stays Terminal-only.

## Error Documents

```json
{
  "schema_version": 1,
  "error": {
    "code": "account_not_found",
    "message": "no account matches \"work\""
  }
}
```

Switch ambiguity adds `candidates` containing account objects.

Remove resolves every selector before mutation. If any selector is missing or
ambiguous, no account is removed and the error contains all resolutions:

Candidate objects are abbreviated in this example; each real candidate uses
the complete account-object shape documented above.

```json
{
  "schema_version": 1,
  "error": {
    "code": "selector_resolution_failed",
    "message": "one or more selectors could not be resolved",
    "resolutions": [
      {
        "selector": "work",
        "status": "ambiguous",
        "account_key": null,
        "candidates": [
          {
            "number": 1,
            "account_key": "user-a::account-a",
            "email": "work-a@example.com"
          },
          {
            "number": 2,
            "account_key": "user-b::account-b",
            "email": "work-b@example.com"
          }
        ]
      },
      {
        "selector": "missing",
        "status": "not_found",
        "account_key": null,
        "candidates": []
      }
    ]
  }
}
```

Resolution status values are `resolved`, `ambiguous`, and `not_found`.

| Error code | Meaning |
|------------|---------|
| `account_not_found` | Switch or alias query has no match |
| `ambiguous_query` | Switch or alias query has multiple matches; `candidates` lists them |
| `invalid_alias` | Alias rejected: empty, all digits, or contains control characters |
| `duplicate_alias` | Alias case-insensitively matches another account; the message names the conflicting account |
| `path_unreadable` | Import source path could not be read |
| `path_not_writable` | Export destination (or a snapshot read) failed to write |
| `app_launch_failed` | Codex App launch failed; the message names the underlying error |
| `no_previous_account` | `switch --previous --json` has no previous key recorded, or it is already active |
| `previous_account_unavailable` | The recorded previous account no longer exists |
| `selector_resolution_failed` | Remove selector resolution failed atomically |
| `curl_unavailable` | Required API refresh cannot find curl |
| `registry_error` | State failed before mutation began |
| `state_uncertain` | Persistence failed after mutation began; run `list --json` before retrying |
| `usage` | Invalid command usage |
