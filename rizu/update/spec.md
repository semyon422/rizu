## Goal

The `rizu/update/` module owns startup-time file update checks and update IO.

## User Experience

- Auto-update should run before the main game controller loads when enabled.
- If files changed, the app should request a restart after update threads are unloaded.

## Architecture Decisions

- `UpdateController` wires persisted config, update IO, and a minimal update draw loop.
- `Updater` contains deterministic file-list diffing and action selection.
- `UpdaterIO` contains asynchronous download, remove, and CRC operations.

## Invariants

- Auto-update is skipped when disabled, when the update URL is empty, or when running from a git checkout.
- The updater writes the refreshed files config only after a successful update pass.
