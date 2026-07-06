## Goal

The `yi/` tree contains the retained UI that is replacing the legacy immediate-mode `ui/` tree. New client UI work should land here, while old `ui/` screens remain as a reference for behavior that has not been migrated yet.

## User Experience

- Players should be able to reach every important client action from the retained UI or command palette before the legacy UI is removed.
- Command palette actions should preserve useful workflows from the old UI even when a full retained screen has not been rebuilt yet.
- Migration should keep behavior discoverable and reversible, especially for chart selection, gameplay, online, multiplayer, package, and database maintenance workflows.

## Architecture Decisions

- The command palette is the preferred temporary bridge for legacy actions that already map cleanly to existing models or controllers.
- Full retained views should replace legacy modal-heavy workflows when the interaction is stateful, visual, or needs repeated editing.
- The old `ui/` tree should not be deleted until its remaining non-visual logic has either moved into `yi/`, moved into model/controller services, or been explicitly retired.

## Future Work and Open Questions

### Command Palette Migration

- **Timings selector**: Replace `TimingsSelectorView` and `TimingsSelectorViewModal` with palette commands for choosing timings/subtimings and applying them to the active replay/scoring context.
- **Play config**: Migrate `PlayConfigView` actions into the palette or retained controls, including rate type, nearest, tap-only, const/custom flags, auto timings, and column order operations.
- **Note skin selection**: `yi` already has a note skin view, but the palette should also support selecting a note skin directly.
- **Online actions**: Audit `OnlineView` and move login/logout/session or other online account actions into retained UI or palette commands.
- **Database maintenance**: Location actions have initial palette coverage, but the database-management half of `MountsView` still needs commands for cache status, recompute actions, diffcalc resets, chartdiff/chartmeta cleanup, and vacuum/debug actions where still wanted.
- **Lobby and multiplayer**: Migrate `LobbyView` and remaining multiplayer screen actions: create/join room, password flow, ready toggle, start/stop match, chart selection, modifier/settings access, chat, and downloads.
- **Result details**: Replace `ReplayInfoModal` with a command that dumps replay/result details to the console or another developer-facing output.

### Retained UI Migration

- **Frame time/profiler view**: Rebuild `FrameTimeView` in `yi` and expose opening/toggling it from the command palette.
- **Gameplay logic audit**: Review old `GameplayView` before removing it. Important behavior includes pause/retry/quit state handling, fail action behavior, focus-loss pause behavior, local offset adjustment, play-speed adjustment, and multiplayer exit conditions.
- **Packages UI**: Rebuild or replace `PackagesView`, including local package listing, opening package folders, remote package download, and source links.
- **Settings coverage**: Ensure retained settings expose any still-useful options that only existed in old `SettingsView`.
