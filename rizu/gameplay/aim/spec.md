## Goal

Implement native osu! circles and sliders, manual input, autoplay, and local diagnostic replay, reusing the existing gameplay clock/audio/session without mania scoring or skin requirements. See [../modes/spec.md](../modes/spec.md) for the larger four-mode plan.

## User Experience

- Import/select a native Mode=0 `.osu` chart and use the ordinary Play or Autoplay command. Non-mania charts are visible without an opt-in setting; search for `1osu` to find Aim charts.
- The selected chart is labelled **AIM (EXPERIMENTAL)**; its difficulty is unavailable rather than presented as a mania difficulty.
- Charts containing circles and sliders are playable. Spinners, empty charts, invalid/budget-exceeding slider geometry, rates outside 0.25x–4x, column reordering, and chart modifiers are rejected with a loading-screen diagnostic. Press Escape to return.
- The temporary playfield shows numbered heads, approach rings, slider paths/balls, tick dots, repeat rings, cursor, HIT/MISS feedback, object/checkpoint counters, and pause state. Use Z/X or the left/right mouse buttons; hold a button and follow slider balls. These prototype bindings are fixed, not edited by the mania binding panel.
- Existing pause/resume and retry controls remain available. Attempts are no-fail. Completion stays on a local summary instead of opening the ordinary score result screen.
- Manual attempts are automatically saved on completion or exit, including attempts with no hits. The latest attempt for a chart replaces its previous diagnostic replay. Retry discards the unfinished attempt and starts fresh.
- At completion, Enter returns to song selection and R loads the saved replay. From song selection, use **Select: Watch Local Aim Replay** in the command palette to load the latest saved attempt. No score is saved/submitted.

## Architecture Decisions

- `chart.osu.AimChart` preserves source-order objects and CS/AR/OD alongside `chart.Chart.aim`. It is copied through `RefChart`/`Restorer`, independently of column-note identity, so simultaneous circles cannot overwrite each other.
- The object DTO preserves circle position/time/type/sounds plus slider source geometry and timing inputs. Separate bounded `SliderPath` and `SliderTiming` helpers feed both gameplay and rendering. See [../../../chart/format/osu/spec.md](../../../chart/format/osu/spec.md). Missing AR uses OD. Settings outside 0–10 are rejected for this prototype.
- `Preparation` computes session bounds without running mania modifiers/difficulty. These bounds are not a persisted/validated competitive chartdiff. Library hashing and difficulty tasks skip mania difficulty creation for native Aim. Existing cached mania-derived values are not migrated or deleted.
- `CircleRules` is headless. The shared `RhythmEngine` dispatches Aim input/update to it while keeping the existing time/audio/BGA infrastructure. No scoring systems are loaded for Aim; `hasResult()` is always false and score saving rejects Aim explicitly.
- `AimPlayfield` renders state but never determines hits. It uses a 512×384 field fitted into a 640×480 reference rectangle and the View world transform for inverse pointer conversion.
- Gameplay input is queued by `gui.UserInterface`. Aim session updates occur from the gameplay screen after queued input is delivered, not from the earlier controller update. This prevents frame-end misses from overtaking timestamped input from that frame. Existing mania scheduling is unchanged.

## Circle Rules

- Radius: `54.4 - 4.48 * CS` chart units.
- Preempt: `1.8 - 0.12 * AR` seconds below AR5, otherwise `1.2 - 0.15 * (AR - 5)`.
- Binary hit window: `±(200 - 10 * OD)` milliseconds, inclusive. A miss is emitted at the deadline when simulation advances strictly past it. No 300/100/50 score classification.
- Only a fresh button press can hit. It must be within the circle radius and time window, and after appearance. Movement alone does not hit. Held-button repeats do not hit.
- Only the earliest unresolved object can consume a press; source order breaks same-time ties. Spatial misses and early presses do not consume objects.
- This is an explicit prototype rule, not full stable/lazer compatibility. Stacking is not applied yet; source positions are used. Complex overlap patterns require later rule review.

## Replay Contract

- The existing `ReplayFrames`/`BinaryEvents` payload is unchanged; it already supports positions and button transitions.
- Input ID 0 is cursor motion; IDs 1/2 are Z/X, 3/4 are mouse buttons. Column 1 carries normal input. Column 2 updates button/cursor state without producing a hit (paused transitions). These semantics belong only to the versioned Aim diagnostic envelope.
- Every delivered pointer sample is recorded without throttling. Button events include the last chart-space cursor position. `ReplayRecorder` snapshots events and coordinate tables instead of retaining mutable references.
- Frames contain judgement-clock time (`engine time - input offset`). Playback advances to `frame time + offset`, then applies the event. Manual play and playback use identical discrete position samples; visual interpolation is not implemented.
- Paused input updates state at frozen chart time and is recorded as state-only input, so a press during pause does not become a replay hit. Autoplay generates ordinary press/release frames, including deterministic same-time ordering.
- Local files: `userdata/replays/aim/<chart-md5>_<index>.json`, format `rizu-aim-sliders-1`. Old `rizu-aim-circles-1` files are accepted only for circle-only charts. The envelope stores chart identity, rate, input offset, and base64-encoded existing compressed frames. Chart geometry/settings come from the matching chart hash. It is not an external osu! replay or a server-submittable score envelope.
- The envelope is intentionally separate from the competitive replay persistence path; no existing score/replay format is silently redefined. Rule changes that invalidate playback require a new diagnostic format identifier.
- Playback restores recorded rate/offset independently of current user settings. Supported playback multipliers are 0.25x–4x; the select UI's linear/exponential adjustment scale does not change the constant-rate simulation. Seek backwards within an attempt is not supported; retry constructs fresh state.

## Slider Rules

- Head judgement uses the circle window and radius. Resolving a slider head unlocks later heads even while its body remains active.
- At each tick/repeat/tail timestamp, any held Aim button and cursor distance within `2.4 * circle radius` counts as a checkpoint hit. Missing the head or any checkpoint makes the final binary object result a miss; later checkpoints can still be recovered. Checkpoint counters are separate from object counters, not competitive scores.
- Checkpoints are processed strictly after their timestamp, after all input at that timestamp. Cursor/button state is held between recorded samples; no render-frame interpolation enters judgement. Paused state-only transitions cannot hit heads but determine held state on resume.
- Final object result occurs after both head expiry and tail. Short sliders therefore cannot finalize before a legal late head press. Session bounds include the latest tail, even if a later head occurs before it.
- Autoplay emits 120 Hz path motion plus exact checkpoint samples and ordinary alternating-key transitions. Unusual overlapping bodies with incompatible cursor positions are not guaranteed perfect autoplay; no judgement bypass is used.
- Checkpoint sounds currently reuse head samples as temporary feedback. Edge-specific samples, looping slide sounds, continuous tracking breaks between checkpoints, stacking, and stable's early tail leniency are not implemented.

## Invariants

- No `ScoreSaver` call, chartplay creation, or score submission is allowed for Aim. No multiplayer play.
- Input is resolved before frame-end expiry. Same-time event order is preserved.
- Replay and autoplay use the same hit rules, not stored judgement outcomes.
- Retry resets rules, cursor/buttons, replay recording, and completion state.
- Rendering and gameplay coordinates share one inverse transform; window size/UI scale must not change judgement geometry.
- Unsupported gameplay objects never silently become playable circles.

## Verification

Focused tests cover source-order geometry/settings through refchart, unsupported objects, gameplay preparation without mania computation, note lock/spatial misses, paused state-only input, immutable recording, local replay persistence, independent physical sources, and manual/replay agreement at 30/60/144 FPS plus long frames, several rates, and nonzero offset. Existing gameplay session/engine tests remain relevant regressions.

Runtime checks were performed in the running LÖVE client via MCP using the existing library chart **yst — the lost dedicated [jump]**, hash `1f5dce5b118d579e9a44021154fc0cf5`, 724 circles. Verified ordinary loading and visible playfield, autoplay 724 hits/0 misses, pause with a non-scoring press, a screen-space mouse hit at zero timing error, fresh retry state, local completion/save, and replay reload from song selection after restarting the client (1 hit/723 misses preserved). Full-chart completion checks used accelerated timeline advancement rather than waiting through the entire song. No competitive result was produced. Existing 7key1scratch autoplay still loaded its skin and scoring. A real slider chart was rejected with a readable diagnostic and return navigation.

Slider runtime checks used **China Dress [Hard]**, hash `93f7b44bb2b687384dc67470d189888c`: 346 objects including 160 sliders. Ordinary loading succeeded; autoplay reached 346 hits/0 misses and 192 checkpoint hits/0 misses with accelerated completion. An injected screen-space mouse press/follow/release hit a curved slider. The saved manual attempt (1/345 objects, 1/191 checkpoints) reproduced through the selection replay command and again after restarting the game. A screenshot confirmed the curved body, follow ball, and follow radius. Spinner charts still show an explicit rejection. These injected checks do not replace a physical-device playtest.

Pointer transforms at multiple sizes/UI scales are covered by headless tests; runtime screenshots were checked at 1920×1080. Audio channels loaded and advanced, but subjective audio synchronization and physical-device feel still need a human playtest. No third-party chart/audio assets were added to the repository.

The engine regression suite passes (119 tests). The broader gameplay suite also exposes two pre-existing failures in untouched `GameplayTimings_test.auto_timings_from_chart` and `ScrollSpeed_test.clamps_to_canonical_range`; both were reproduced using source/test files from HEAD. They are not fixed by this prototype.

## Future Work and Open Questions

- Add spinners; implement stacking and review overlap/note-lock and continuous slider tracking compatibility.
- Replace fixed bindings and the latest-only diagnostic replay UI when broader mode input/replay requirements are settled.
- Bound local replay decoding and recording memory for very long attempts; the current diagnostic store is a trusted local developer facility, not an untrusted replay import endpoint.
- Provide guaranteed built-in hitsound fallback when chart/default samples are unavailable.
- Remove or migrate historical mania-derived Aim library data only through an explicit migration; current display masks the irrelevant difficulty value.
