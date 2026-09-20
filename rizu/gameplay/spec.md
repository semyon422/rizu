# Gameplay Session Architecture (`rizu.gameplay`)

## Goal
The gameplay module owns the orchestration of a single play attempt. It should coordinate timing, input source selection, replay recording, and game-facing integrations without leaking those responsibilities into lower-level engine code.

## User Experience
- Starting a song should create a fresh gameplay session with deterministic timing and clean state.
- Retrying a chart should behave like a brand-new attempt rather than reusing mutable state from the previous play.
- The retry binding defaults to the backtick/tilde (`~`) key. Retry and play-to-pause require holding the key for their configured duration; early release cancels the transition. Resume uses a countdown (no hold required), cancelled by pressing pause again, matching the legacy UI. Zero duration executes immediately. `GameplayInteractor:update()` consumes `PauseModel.needRetry` by starting a fresh attempt; reloading the pause model clears the request and stops its tween. Multiplayer rooms continue to disallow local transitions.
- The Gameplay settings section exposes preparation time and separate play-to-pause, pause-to-play, play-to-retry, and pause-to-retry durations. `PauseModel` now receives the modern settings store and reads `gameplay.time.*`, not legacy `settings.gameplay.time`; legacy Lua values are not automatically migrated.
- Manual play, autoplay, and replay should all feel like the same session flow from the player's perspective, differing only in the source of input events.
- Gameplay input bindings follow the computed chart input mode after modifiers, so converted charts use bindings for their effective key count.

## Experimental Game Modes

Requirements for the Aim, Catch, Taiko, and SDVX prototypes are tracked in [modes/spec.md](modes/spec.md). The Aim implementation and its limitations are documented in [aim/spec.md](aim/spec.md), and the native prototypes in [catch/spec.md](catch/spec.md), [taiko/spec.md](taiko/spec.md) and [sdvx/spec.md](sdvx/spec.md). The work covers core mechanics, ordinary chart selection, autoplay/replays, and investigation for future skinning work without mode-specific scoring or score submission.

- Experimental mode playfields live in `rizu.gameplay`: `rizu.gameplay.Playfield` is the generic `gui.View` host and selects the Aim, Catch, Taiko, or SDVX renderer from the loaded engine. The application UI only places this host; it does not construct or select mode-specific renderers. Renderers use only `gui` and Love2D drawing primitives, so they do not depend on `ui.Resources` or screen implementation details.

## Core Components

- `rizu.GameplaySession`: coordinates `RhythmEngine`, manual or automated players, and replay recording for one attempt.
- `rizu.gameplay.GameplayInteractor`: bridges the gameplay session to the surrounding UI or controller layer and handles peripheral integrations such as presence updates.

## Architecture Decisions

### ADR: One Session Per Attempt
- A `GameplaySession` instance must be created for each play or retry.
- Do not reuse the same session across retries.
- Session-scoped state such as recorders, autoplay mode, and result lifecycle belongs to the session instance.

### ADR: Play Type Is Session-Level Policy
- Choose the active input source with `setPlayType(type)`, where `type` is `"manual"`, `"auto"`, or `"replay"`.
- Autoplay and replay behavior should remain session-level concerns rather than adding mode-specific branches deep inside core engine timing logic.

### ADR: Engine Result Validity Stays In Engine Contracts
- `RhythmEngine:hasResult()` is the gate for whether a play can produce a score.
- Session code may coordinate around this, but should not replace or bypass the engine's result validity rules.

### ADR: Gameplay Resource Loading Is Threaded
- Gameplay startup loads chart audio, images, and packed sample resources through `ResourceLoader:loadAsync()` so the chart-loading screen can continue updating while filesystem reads and archive unpacking run in a worker thread.
- Video resources keep their resolved virtual paths instead of being copied into the resource snapshot. Gameplay BGA opens and decodes them through `AsyncVideoEngine` in a dedicated LÖVE thread, using the same bounded frame queue and main-thread GPU upload path as select preview.
- The async path returns resource and chart snapshots that are applied on the main thread. Chart snapshots use packed primitive arrays, interned note columns/types, numeric visual-point references, and sparse dynamic note data instead of one transfer table per note or visual point. This keeps LÖVE Channel result handling bounded for dense charts. The main thread restores ordinary runtime chart objects incrementally with a 4 ms work budget and yields between chunks, so dense charts do not monopolize one frame.
- Rhythm engine setup and `play()` happen only after both snapshots are installed.
- Editor resource loading stays synchronous for now, because editor startup has different UI/state expectations and was not part of the gameplay-start lag fix.

### ADR: Durable Score Submission Diagnostics
- Every manual submission attempt writes a bounded structured entry to `userdata/logs/score_submissions.log` and mirrors the same entry to the console, including the replay/chart identity and whether submission was skipped, accepted, rejected, or raised an exception.
- Accepted entries include the durable server job and chartplay identifiers plus the initial compute state so reports can be correlated with server queue records. While connected, the client polls accepted jobs for up to ten minutes and logs state/attempt changes, terminal failures, and successful side-effect completion.
- Rejected submissions retain the score-engine event dump under `userdata/logs/score_submission_<replay_hash>.events`; event data is not dumped for accepted asynchronous jobs.
- The diagnostic log is capped at 1 MiB and retains its newest complete entries.

## Testing Patterns

- Advance time with `GameplaySession:update(global_time)`.
- Initialize timing in the correct order: set global time before calling `re:play()` or `re:update()` on the underlying engine/session objects.
- Use `sea.chart.TestChartFactory` to create test charts programmatically instead of relying on file parsing for gameplay tests.

Example:

```lua
local TestChartFactory = require("sea.chart.TestChartFactory")
local tcf = TestChartFactory()
local res = tcf:create("4key", {
	{time = 1, column = 1},
	{time = 2, column = 2, end_time = 3},
	{time = 4, velocity = {0.5}},
})
```

## Invariants

- Input binding stays in `GameplayInteractor`. Paused input continues to update engine captures, button state, and replay frames at frozen chart time; note input is deferred by `InputPauser` until resume.
- While paused, a press first tries to recapture an unmatched note held at pause time, before normal note priorities. Otherwise a following clear note can steal the press from the held LN, causing a false release on resume. Recapture must also work when rebinding assigns a new event ID.
- Resume reconciles final button state: newly held buttons press notes, released buttons release notes, and a released/repressed LN remains held without an extra note input.

- Deferred play/resume clock resynchronization must wait for a fresh global frame timestamp. A gameplay update in the same frame as loading must not consume it: the next frame includes loading time, which must not advance chart time or its monotonic floor.
- Gameplay video decoding must not run from `BgaView:draw()` or any other main-thread render path. The draw path may request/present an already decoded frame and upload it to the GPU.
- Gameplay chart worker results must remain channel-friendly: do not reintroduce per-note or per-visual-point transfer tables into `ChartSnapshot`. Optional data belongs in sparse arrays/maps, and repeated strings should stay interned.
- Restored charts must remain ordinary mutable `chart.Chart` instances; the packed snapshot is only a worker-transfer representation and must preserve chart data, resources, timing points, visual properties, note data, and mode-specific payloads. Snapshot construction accepts only an already computed and validated chart. Restoration may therefore copy derived point/visual state and rebuild note links without re-sorting and re-validating the same arrays on the main thread.
- Incremental restoration must abort before publishing its chart when `GameplayInteractor.load_generation` changes. An obsolete load must never overwrite `ComputeContext` after a newer load or unload starts.
- Gameplay resource snapshots retain resolved video paths but not full video file contents, so large BGA files are not duplicated across the resource-loading thread boundary.

## Implementation Notes

- Keep replay, autoplay, and scoring boundaries explicit.
- If a change affects user-facing gameplay lifecycle, document it here and in lower-level specs if engine behavior also changes.
