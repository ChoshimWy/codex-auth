# `codex-auth alias`

## Usage

```shell
codex-auth alias set <query> <alias>
codex-auth alias clear <query>
```

## Selector Rules

`<query>` resolves from stored local data only. It does not trigger API refresh.

Selectors can match:

- displayed row number,
- alias fragment,
- email fragment, or
- account name fragment.

If one account matches, the command updates that account immediately. If multiple accounts match, the command falls back to interactive selection in a TTY.

## Set Alias

`codex-auth alias set <query> <alias>` stores an alias in `registry.json` for the matched account.

- Empty aliases are rejected.
- All-digit aliases are rejected because numeric selectors already refer to displayed row numbers.
- Alias comparison is case-insensitive for duplicate detection.
- Changing an alias updates only stored registry metadata.

## Clear Alias

`codex-auth alias clear <query>` removes the stored alias for the matched account.

If the alias is already empty, the command reports that state and leaves the registry unchanged.

## JSON Output

```shell
codex-auth alias set <query> <alias> --json
codex-auth alias clear <query> --json
```

- `--json` may appear anywhere after the `set`/`clear` subcommand. JSON mode
  never falls back to the interactive picker: an ambiguous query fails with
  `ambiguous_query` and `candidates`, and no match fails with
  `account_not_found`.
- The success document contains `"command": "alias"`, the `operation` (`set`
  or `clear`), and the `updated` account object. After `clear`, the account's
  `alias` is `null`.
- Validation failures use `invalid_alias` (empty, all digits, or control
  characters) and `duplicate_alias` (case-insensitive collision; the message
  names the conflicting account).
- Persistence failures after a mutation began report `state_uncertain`; run
  `list --json` before retrying.
- `--json` is always consumed as the flag wherever it appears, so a selector
  or alias value cannot be the literal string `--json`. Other dash-prefixed
  values (such as `-x`) remain valid alias values.

See [json-api.md](../json-api.md) for the versioned contract.
