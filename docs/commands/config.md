# `codex-auth config`

## Usage

```shell
codex-auth config live --interval <seconds>
```

## Live Refresh Config

`config live --interval <seconds>` sets the live TUI refresh interval.

- Allowed range: `5` to `3600`.
- Stored in `registry.json` as top-level `interval_seconds`.

## API Refresh

API-backed refresh is the default for supported foreground paths. Use per-command `--skip-api` to run a foreground command with local data only. Older `registry.json` files may contain an `api` object; current builds ignore it and omit it on the next registry save.

API behavior and endpoint details live in [docs/api.md](../api.md).

## JSON Output

```shell
codex-auth config live --interval <seconds> --json
codex-auth config get --json
```

- Both forms report `{"command":"config","section":"live","interval_seconds":…}`.
- `config get` requires `--json`.

See [json-api.md](../json-api.md) for the versioned contract.
