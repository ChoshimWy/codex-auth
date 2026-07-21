# Codex Switcher

`CodexSwitcher` is the macOS menu-bar companion for `codex-auth`.

Product requirements and the JSON-contract boundary are defined in the parent
repository's [macOS status bar app requirements](../../docs/macos-status-bar-app-requirements.md).

## Planned project layout

- `Sources/CodexSwitcher/App` — app entry point and scene composition.
- `Sources/CodexSwitcher/DesignSystem` — reserved for Liquid Glass visual
  tokens and shared UI primitives.
- `Sources/CodexSwitcher/Features` — reserved for the account panel, status
  item, and settings features.
- `Sources/CodexSwitcher/Infrastructure` — reserved for the structured
  `codex-auth` process client and persistence-free integration boundary.
- `Sources/CodexSwitcher/Models` — reserved for JSON-contract models and
  view state.
- `Tests/CodexSwitcherTests` — bootstrap coverage now; unit and
  interaction-focused coverage will be added with features.

The bootstrap scene intentionally shows an unavailable state. Account actions
will be added only through the documented `--json` interface.
