# Engine rework

Written on 2026-10-14, branch `refactor2025`, while adding `rizu.api.Gameplay`. These are the places where the
gameplay core could not be exposed through the API cleanly. Each one is worked around in `rizu/api/Gameplay.lua`
today; the workaround is named so it can be deleted when the core is fixed.

Not a release blocker. The API hides all of it, so UIs and skins written against `api.gameplay` keep working
through the rework.

## The root cause: two engine families

There are two implementations, not five:

- **Mania**: `rizu/gameplay/mania/Engine.lua`, `RhythmEngine + {}`. Logic, input, visual and score engines;
  notes in `visual_engine.visible_notes`; scoring in `score_engine`.
- **Everything else**: aim, taiko, catch and sdvx are all `RulesEngine + {}` (`rizu/engine/RulesEngine.lua`).
  One `rules` object per mode, with `hits` and `misses` only, no score engine, no visible-note list.

`game.rhythm_engine` is typed as the base `rizu.RhythmEngine`, so every caller that needs anything
mode-specific probes fields (`engine.score_engine and …`, `engine.isColumnPressed ~= nil and …`) and casts.
Most of the items below are this split showing up in a different place.

Direction: one engine contract that both families implement — judgements, counts, progress and "the play is
over" — with the mode-specific parts (note drawing, rules) behind it. Mania's `ScoreEngine` becoming optional
for a mode, or the rules modes reporting judgements into the same sequence, are both ways there.

## Findings

Most important first.

### 1. The game does not know when a play ends

The UI checks `getProgress() >= 1` every frame (`ui/screens/gameplay/Gameplay.lua`, `observeCompletion`). For the
rules modes it then sets `gameplayInteractor.complete = true` and pauses from outside.

- Workaround: `Gameplay:finish()`, and no `"finished"` event in the API.
- Fix: `GameplaySession` (or the interactor) detects the end itself and emits it. Removes `finish()`, the
  `complete` flag poked from outside and the per-frame polling.

### 2. The pause model has no events

`sphere/models/PauseModel.lua` is a string state machine driven by `flux` tweens. Hold states are built by
concatenation (`state .. "-" .. newState`) and transitions happen inside the tween with no callback.

- Workaround: `getState()` / `getStateProgress()` polled per frame; the API documents six literal strings in
  `rizu.api.Gameplay.State`. No `"state_changed"` event.
- Also: `PauseModel` calls `love.mouse.setVisible`, which is UI work in the backend.
- Fix: explicit states with a change callback; move cursor visibility to the UI.

### 3. The UI drives part of the engine's frame

Input reaches the game only through the UI forwarding events (`Gameplay:receive`). The rules modes have
`deferred_input = true` and also need a second update pass after input
(`GameplayInteractor:update(dt, true)`), which the UI has to call.

- Workaround: `Gameplay:update(dt)`, documented as "call after the frame's events went to receive()".
- Fix: the game receives input events itself while gameplay is loaded and runs both passes in its own update.
  A UI that forgets either call today breaks gameplay.

### 4. Gamemode data lives on subclasses with different shapes

- Hits are counted twice, differently: `score_engine.scores.base.hitCount/missCount` for mania,
  `rules.hits/misses` for the rest.
- Score, accuracy and combo exist only for mania.
- Visible notes and `isColumnPressed` exist only for mania.

- Workaround: `getHitCounts()` branches on `score_engine`; `getScore/getAccuracy/getCombo` return nil;
  `getVisibleNotes()` returns an empty table outside mania.
- Fix: part of the shared engine contract above.

### 5. The judgement sequence is untyped

`score_engine.sequence` is a list of tables keyed by score-system name. A judge is
`slice[judgesSource:getKey()].visual_judge or last_judge`, a delta is `slice.misc.deltaTime`, the kind is
`base.isMiss` / `base.isEarlyHit`. The same decoding is in `Result:getHits()` and `Gameplay:getJudgement()`,
and the user's `HitErrorView` has a third copy.

- Fix: one typed record per judgement (`kind`, `delta`, `judge`, `time`) written by the score engine.

### 6. Background animation is drawn by a skin view, not the engine

`rizu/skin/views/BgaView.lua` reads the BGA, video and sprite engines from `game` and does the drawing. There is
no engine-side draw call to wrap.

- Workaround: none; `drawBackgroundAnimation(width, height)` from the skin review is not in the API.
- Fix: move the drawing next to `BgaEngine`; `BgaView` and the API call it.

### 7. Pointer input needs the UI's viewport

The gameplay viewport is UI config (`gameplay_viewport_*`), but `Playfield:toChart` needs it to map the mouse
into chart space.

- Workaround: `Gameplay:movePointer(x, y, width, height, transform, time)`.
- Fix: the renderer remembers the viewport of its last `draw`, or the viewport moves to gameplay settings.

### 8. The local-replay flow for the rules modes is spread across the interactor

Watching the kept replay is `loadLocalReplay(hash, index, mode)` + `retry()`, the result is the
`replay_status` string, and the attempt end is the `complete` flag.

- Workaround: `Gameplay:watchLocalReplay()` and the status returned by `finish()`.
- Fix: one backend call; goes away mostly with 1.

### 9. Engine notes have no chart time

`rizu.VisualNote` exposes `start_dt` / `end_dt` (already scaled by scroll speed, `end_dt` on long notes only),
`getColumn()` and `getState()`. The `time` / `end_time` fields named in the API review come from the 320 skin's
own preview tables, not the engine. Note states are mania logic strings (`"startPassedPressed"`, …).

- Workaround: `rizu.api.Note` declares only what exists.
- Fix: decide whether skins get chart time; if so, add it to the visual note, not a copy.

### 10. Smaller ones

- Saving the score is a side effect of `GameplayInteractor:unloadGameplay` ("got far enough" is checked there).
  `Gameplay:close()` inherits it silently.
- `changePlayState` does nothing in multiplayer, with no way for the UI to know.
- `game.rhythm_engine` is recreated per play (`recreateRhythmEngine`), so nothing may hold it; the API re-reads
  it on every call. Fine, but Lua skins still receive `game` and can hold it.
- Skin editor properties are closures with a type per renderer (step 11 of `rizu/skin/REVIEW.md`).

## Not done in the API, waiting on this

- Events `"finished"` and `"state_changed"` (1, 2).
- `drawBackgroundAnimation` (6).
- Lua skins receiving `api` instead of `game`: switching `SkinRegistry:createRenderer` breaks the three skins in
  `userdata/dlc/skins_rizu` until they are ported.
- `api.play:start(f)`: `ui/screens/chart_loading/ChartLoading.lua` still calls `gameInteractor` directly.

## Order of work

1. Play end detected by the session, with an event (1, 8). Smallest change, removes the most UI logic.
2. Pause states with a callback; cursor visibility to the UI (2).
3. The game takes input and runs both update passes itself (3).
4. One engine contract for both families: judgements, counts, typed sequence (4, 5).
5. BGA drawing next to the engine (6), viewport ownership (7), note time (9).
