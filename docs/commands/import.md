# `codex-auth import`

## Usage

```shell
codex-auth import <path> [--alias <alias>]
codex-auth import --cpa [<path>] [--alias <alias>]
codex-auth import --purge [<path>]
```

## Standard Import

- A file path imports one auth/config file.
- A directory path imports direct child `.json` files from that directory.
- Directory imports are non-recursive.
- `--alias` applies only to a single imported file.
- Directory import ignores `--alias`.

## CLIProxyAPI Import

`--cpa` imports flat [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) token JSON.

- Without a path, it scans `~/.cli-proxy-api/*.json`.
- With a directory path, it scans direct child `.json` files from that directory.
- With a file path, it imports that single CPA file.
- CPA input is converted in memory to the current auth snapshot format before writing managed account files.
- `--cpa` cannot be combined with `--purge`.

## Purge Import

`--purge` rebuilds `registry.json` from existing auth snapshots.

- Without a path, it scans `~/.codex/accounts/`.
- With a path, it scans auth files from that directory.
- It also tries to import the current `~/.codex/auth.json` last.
- It clears and rebuilds account records, stored usage, active-account activation time, and local rollout dedupe state.
- It does not delete old snapshot files or backups.

Use `--purge` as a recovery tool when the registry index is out of sync with the auth files on disk.

## Output

- `stdout` receives scan lines, imported/updated rows, and summaries.
- `stderr` receives skipped rows and warnings.
- Parse failures render as `InvalidJSON`.
- Validation failures keep explicit names such as `MissingEmail` or `MissingChatgptUserId`.

## JSON Output

```shell
codex-auth import <path> [--alias <alias>] --json
codex-auth import --cpa [<path>] --json
codex-auth import --purge [<path>] --json
```

- The success document reports the `mode` (`standard`, `cpa`, `purge`), the
  resolved `source`, one `results` row per file event (`path`, `status` =
  `imported`/`updated`/`skipped`, optional `email`, optional `reason`), the
  aggregate `imported_count`/`updated_count`/`skipped_count`, and the
  registry's `active_account_key` after the import. Purge success adds
  `"registry_rebuilt": true`.
- Per-file failures stay result rows for multi-file scans; a single-file
  import that fails validation escalates to a command-level `registry_error`
  (the engine's `fail_report_on_malformed` behavior, shared with the human
  CLI). An unreadable import source is a handled `path_unreadable` error.
- Imported accounts do not become active. Run `list --json` after an import
  to reconcile rows.

See [json-api.md](../json-api.md) for the versioned contract.
