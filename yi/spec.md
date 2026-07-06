## Goal

The `yi/` tree contains the retained UI that replaced the legacy immediate-mode `ui/` tree. New client UI work should land here.

## User Experience

- Players should be able to reach every important client action from the retained UI or command palette before the legacy UI is removed.
- Command palette actions should preserve useful workflows from the old UI even when a full retained screen has not been rebuilt yet.
- Migration should keep behavior discoverable and reversible, especially for chart selection, gameplay, online, multiplayer, package, and database maintenance workflows.

## Architecture Decisions

- The command palette is the preferred temporary bridge for legacy actions that already map cleanly to existing models or controllers.
- Full retained views should replace legacy modal-heavy workflows when the interaction is stateful, visual, or needs repeated editing.
- The old `ui/` tree has been removed. Legacy-only workflows that still matter should return as retained `yi` views, command palette actions, or model/controller services rather than restoring the deleted tree.

## Future Work and Open Questions

### Command Palette Migration

- **Timings selector**: Initial palette coverage exists for choosing timings and osu! score-version subtimings. Future work should cover arbitrary timing-window editing or a retained replacement for `TimingsModalView`.
- **Play config**: Initial palette coverage exists for rate type, nearest, tap-only, const/custom flags, auto timings, and column order operations. Future work should decide which of these also need retained controls.
- **Note skin selection**: Initial palette coverage exists for selecting the current input mode's note skin. Future work should cover richer skin configuration.
- **Online actions**: Initial palette coverage exists for login/logout/quick login. Future work should audit any remaining session or account actions.
- **Database maintenance**: Initial palette coverage exists for cache status, recompute actions, diffcalc resets, chartdiff/chartmeta cleanup, and vacuum/debug actions. Future work should review which destructive commands should get a proper retained confirmation flow.
- **Lobby and multiplayer**: Initial palette coverage exists for create/join/leave room, ready toggle, start/stop match, selected-chart sync, replay-base sync, chat, and room chart download. Future work should rebuild the actual lobby/multiplayer retained experience.
- **Result details**: Initial palette coverage exists for dumping replay/result details to the console.

### Retained UI Migration

- **Frame time/profiler view**: The legacy frame-time/profiler overlay is available from `yi` and can be opened/toggled from the command palette. Future work may convert it to retained UI if the debug surface needs deeper integration.
- **Gameplay logic audit**: Continue auditing gameplay behavior against retained `yi`/`rizu` code and historical commits if needed. Important behavior includes pause/retry/quit state handling, fail action behavior, focus-loss pause behavior, local offset adjustment, play-speed adjustment, and multiplayer exit conditions.
- **Packages UI**: Rebuild or replace `PackagesView`, including local package listing, opening package folders, remote package download, and source links.
- **Settings coverage**: Ensure retained settings expose any still-useful options that only existed in old `SettingsView`.
