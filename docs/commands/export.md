# `codex-auth export`

## Usage

```shell
codex-auth export [<dir>]
codex-auth export --cpa [<dir>]
```

## Standard Export

- Exports stored account auth snapshots.
- A directory path writes direct child `*.auth.json` files to that directory.
- Without a directory path, files are written to `CODEX_HOME/accounts/backup`.
- The exported directory can be imported with `codex-auth import <dir>`.

## CLIProxyAPI Export

`--cpa` exports flat [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) token JSON.

- A directory path writes direct child `.json` files to that directory.
- Without a directory path, files are written to `CODEX_HOME/accounts/backup`.
- The exported directory can be imported with `codex-auth import --cpa <dir>`.

## Output

- `stdout` receives the number of exported accounts and destination directory.

## JSON Output

```shell
codex-auth export [<dir>] [--cpa] --json
```

- The success document reports the `format` (`standard` or `cpa`), the
  resolved `destination`, `exported_count`, and `skipped_count` (CPA mode
  skips API-key accounts).
- A destination that cannot be written is a handled `path_not_writable`
  error.

See [json-api.md](../json-api.md) for the versioned contract.
