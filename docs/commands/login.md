# `codex-auth login`

## Usage

```shell
codex-auth login
codex-auth login --device-auth
```

## Behavior

- Runs `codex login`, or `codex login --device-auth` when requested.
- Reads the resulting `auth.json` from the active Codex home.
- Adds or updates the current account in `registry.json`.
- Stores a managed account snapshot under `accounts/<account file key>.auth.json`.
- Makes the logged-in account active when import succeeds.

## Notes

- `codex` must be available on `PATH`.
- Login-created accounts do not get an alias. Use `import <file> --alias <alias>` when an alias is needed.
- Invalid or incomplete auth files are rejected with the same auth validation rules used by `import`.

## JSON Output

```shell
codex-auth login --device-auth --json
```

- Drives `codex login --device-auth` with piped stdout and emits one JSON
  document per phase on stdout: `awaiting_user` (verification URL and user
  code, flushed immediately), then `completed` (active account key and the
  account object) or `failed` (non-secret message). All phase documents exit
  `0`; errors before the first phase document use the standard JSON error
  documents with exit `1`.
- `login --json` requires `--device-auth`; the interactive login flow is
  Terminal-only.
- The login runs against a temporary `CODEX_HOME`, so a failed or killed
  login never mutates the real registry.

See [json-api.md](../json-api.md) for the versioned contract.
