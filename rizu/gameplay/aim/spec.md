## Goal

Implement native osu! circles, sliders, and spinners, manual input, autoplay, and local diagnostic replay, reusing the existing gameplay clock/audio/session without mania scoring or skin requirements. See [../modes/spec.md](../modes/spec.md) for the larger four-mode plan.

## User Experience

- Import/select a native Mode=0 `.osu` chart and use the ordinary Play or Autoplay command. Non-mania charts are visible without an opt-in setting; search for `1osu` to find Aim charts.
- The selected chart is labelled **AIM (EXPERIMENTAL)**; its difficulty is unavailable rather than presented as a mania difficulty.
- Charts containing circles, sliders, and spinners are playable. Empty charts, invalid spinner durations, invalid/budget-exceeding slider geometry, rates outside 0.25x–4x, column reordering, and chart modifiers are rejected with a loading-screen diagnostic. Press Escape to return.
- The temporary playfield shows numbered heads, approach rings, slider paths/balls, tick dots, repeat rings, cursor, HIT/MISS feedback, object/checkpoint counters, and pause state. Use Z/X or the left/right mouse buttons; hold a button and follow slider balls, or rotate around the playfield centre for spinners. These prototype bindings are fixed, not edited by the mania binding panel.
- Existing pause/resume and retry controls remain available. Attempts are no-fail. Completion stays on a local summary instead of opening the ordinary score result screen.
- Manual attempts are automatically saved on completion or exit, including attempts with no hits. The latest attempt for a chart replaces its previous diagnostic replay. Retry discards the unfinished attempt and starts fresh.
- At completion, Enter returns to song selection and R loads the saved replay. From song selection, use **Select: Watch Local Aim Replay** in the command palette to load the latest saved attempt. No score is saved/submitted.

## Architecture Decisions

- `chart.osu.AimChart` preserves source-order objects and CS/AR/OD alongside `chart.Chart.aim`. It is copied through `RefChart`/`Restorer`, independently of column-note identity, so simultaneous circles cannot overwrite each other.
- The object DTO preserves circle position/time/type/sounds plus slider source geometry/timing inputs and spinner end times. Separate bounded `SliderPath` and `SliderTiming` helpers feed both gameplay and rendering. See [../../../chart/format/osu/spec.md](../../../chart/format/osu/spec.md). Missing AR uses OD. Settings outside 0–10 are rejected for this prototype.
- Gameplay worker decoding returns both parser failures and thrown decode/index errors as `{error = string}`. The caller raises the diagnostic on the main coroutine so ChartLoading can display it; decode errors must not escape as fatal thread errors.
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
- This is an explicit prototype rule, not full stable/lazer compatibility. Stacking is applied to a separate runtime chart; complex overlap patterns still require later rule review.

## Replay Contract

- The existing `ReplayFrames`/`BinaryEvents` payload is unchanged; it already supports positions and button transitions.
- Input ID 0 is cursor motion; IDs 1/2 are Z/X, 3/4 are mouse buttons. Column 1 carries normal input. Column 2 updates button/cursor state without producing a hit (paused transitions). These semantics belong only to the versioned Aim diagnostic envelope.
- Every delivered pointer sample is recorded without throttling. Button events include the last chart-space cursor position. `ReplayRecorder` snapshots events and coordinate tables instead of retaining mutable references.
- Frames contain judgement-clock time (`engine time - input offset`). Playback advances to `frame time + offset`, then applies the event. Manual play and playback use identical discrete position samples; visual interpolation is not implemented.
- Paused input updates state at frozen chart time and is recorded as state-only input, so a press during pause does not become a replay hit. Autoplay generates ordinary press/release frames, including deterministic same-time ordering.
- Local files: `userdata/replays/aim/<chart-md5>_<index>.json`, format `rizu-aim-tracking-1`. This enables sampled slider tracking and early tail judgement; `rizu-aim-stacking-1` retains checkpoint-only slider rules. Formats before stacking use unshifted source geometry. Old `rizu-aim-circles-1` files are accepted only for circle-only charts; `rizu-aim-sliders-1` files require charts without spinners. The envelope stores chart identity, rate, input offset, and base64-encoded existing compressed frames. Chart geometry/settings come from the matching chart hash. It is not an external osu! replay or a server-submittable score envelope.
- The envelope is intentionally separate from the competitive replay persistence path; no existing score/replay format is silently redefined. Rule changes that invalidate playback require a new diagnostic format identifier.
- Playback restores recorded rate/offset independently of current user settings. Supported playback multipliers are 0.25x–4x; the select UI's linear/exponential adjustment scale does not change the constant-rate simulation. Seek backwards within an attempt is not supported; retry constructs fresh state.

## Slider Rules

- Head judgement uses the circle window and radius. Resolving a slider head unlocks later heads even while its body remains active.
- At each tick/repeat/tail timestamp, any held Aim button and cursor distance within `2.4 * circle radius` counts as a checkpoint hit. Missing the head or any checkpoint makes the final binary object result a miss; later checkpoints can still be recovered. Checkpoint counters are separate from object counters, not competitive scores.
- Checkpoints are processed strictly after their timestamp, after all input at that timestamp. Cursor/button state is held between recorded samples; no render-frame interpolation enters judgement. Paused state-only transitions cannot hit heads but determine held state on resume.
- Final object result occurs after both head expiry and tail. Short sliders therefore cannot finalize before a legal late head press. Session bounds include the latest tail, even if a later head occurs before it.
- Autoplay emits 120 Hz path motion plus exact checkpoint samples and ordinary alternating-key transitions. Unusual overlapping bodies with incompatible cursor positions are not guaranteed perfect autoplay; no judgement bypass is used.
- Current attempts additionally check held state and follow-circle distance on every non-paused input event and on a chart-time 240 Hz grid anchored to each slider head. This detects releases/excursions between checkpoints and motion of the slider away from a stationary pointer. These are bounded deterministic samples, not mathematical continuous collision detection. The first tracking failure after a successful head permanently invalidates the binary object result; later checkpoints remain recoverable. Tracking does not run before head judgement or after the early tail.
- Tail judgement occurs 36 ms before the visual endpoint, but never before the final span midpoint or the last real tick/repeat. It samples the ball at that time. Release after this point is allowed; visual completion and session bounds still use the true endpoint. This is explicit prototype leniency, not exact stable compatibility.
- Tracking events use the same strict timestamp ordering as checkpoints. Paused state-only input is exempt from immediate tracking failures; the resumed held/cursor state is used by subsequent grid samples. Same-time physical key transfers require the new key to be pressed before the old one is released.
- The schedule is bounded to fewer than 250000 tracking/checkpoint entries at preparation; no render-frame duration enters tracking judgement. Older replay formats keep checkpoint-only judgement and exact-end tails.
- Slider head, repeat and tail samples use source edge masks/sets, with hitnormal included alongside clap/whistle/finish. Zero edge sets inherit object/timing/general sets. Object sample index/volume override timing values; bank 0/1 uses unsuffixed filenames and higher banks retain an unsuffixed fallback. Custom sample filenames apply only to the head. Tick samples use `normal|soft|drum-slidertick` at the tick's timing-point sample set/index/volume, not the head hitsound.
- `SliderSamples.prepare` resolves audio during gameplay preparation before resource lookup and refchart transfer. Sample selection for tails uses the real endpoint's timing point; playback occurs at the successful early tail judgement. Failed checkpoints are silent and successful events dispatch once. This improves audio for older replays too, without changing their judgement rules or envelope version.
- Missing tick files fall back to a project-generated 50 ms click in `resources/aim/hitsounds`; chart and user sounds remain higher priority. Looping slide/whistle sounds and exact stable audio-envelope parity remain future work.

## Spinner Rules

- Spinners occupy their source start/end interval and rotate around the fixed field centre `(256, 192)`. End times survive refchart snapshots and extend session bounds. Missing, non-finite, or non-positive durations fail loading. Spinners have no clickable head and do not block later circle/slider heads.
- Hold any Aim button and move around the centre. Progress is the absolute signed sum of shortest angular deltas between timestamped input samples, in turns. Either direction works; reversing direction cancels prior rotation rather than allowing small back-and-forth jitter to farm progress.
- The first eligible sample establishes an angle baseline. Unheld input, paused state-only events, samples outside the interval, or entry into the 16-unit centre dead zone reset this baseline without adding rotation. Same-time samples add no rotation. Deltas are capped at 8 turns/second of chart time; sparse input cannot infer revolutions greater than half a turn per sample.
- Required turns are `durationSeconds * (1.5 + 0.15 * OD)`. This fractional binary target and signed accumulation are explicit prototype rules, not stable/lazer spinner compatibility, inertia, RPM scoring, bonus rotations, or HP behavior.
- A single hit/miss is emitted strictly after the end timestamp, allowing input at the exact end. No updates/render frames add rotation. A successful end plays the object's existing sample; no looping spinner sound is implemented.
- Manual pause on a chart with spinners records a state-only motion marker even if the mouse does not move, resetting the angular baseline identically in replay. Other paused inputs retain the shared state-only contract.
- Autoplay uses ordinary held-button input and 120 Hz circular motion at 4 turns/second on a 100-unit radius, including the endpoint. Retry constructs fresh rotation/baseline state. Overlapping objects requiring incompatible cursor movement remain outside guaranteed-perfect autoplay.

## Stacking

- `AimChart` preserves StackLeniency; a missing value uses osu!'s 0.7 default, explicit zero is retained, and values outside 0–1 are rejected.
- `Stacking` computes modern reverse-pass heights for format versions above 5 and a legacy forward pass for earlier charts. Heads within strictly 3 chart units can stack within `preempt * StackLeniency`; circle stacks consider preceding slider end times. Slider-tail overlaps produce negative heights, and modern slider endpoints respect repeat parity. Spinners are excluded.
- Runtime displacement is `-height * circleRadius / 10` on both axes. The head, complete slider path, and copied control points move together. Source DTOs/refcharts remain unchanged; retry always recomputes from source, never from shifted data.
- Rules, rendering, checkpoint positions, and autoplay share runtime geometry. Earlier heads are drawn above later stack members. Autoplay from an already-prepared rules chart explicitly skips a second stacking pass.
- Replay formats `rizu-aim-stacking-1` and `rizu-aim-tracking-1` select stacked geometry. Earlier diagnostic formats explicitly disable stacking in the engine, retaining their original positions and outcomes.
- Preparation validates the bounded stacking pass before loading gameplay resources. Work is capped at two million candidate comparisons. Full-chart algorithms are adapted from osu! lazer; attribution and MIT notice are in `Stacking.LICENSE`. Exact stable integer/float rounding quirks are not emulated.

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

Spinner runtime checks used **Zero Centimeters (TV Size) [Easy]**, hash `b63dbea735c5a7909b75b479ed7220e2`: the previously rejected chart loaded with 92 objects including a final spinner. Accelerated autoplay completed at 92 hits/0 misses. A screen-space injected manual rotation hit the spinner; its attempt saved as 1 hit/91 misses and reproduced after restarting the client with identical rotation (`11.685920777247109` turns) and results. Rendering was checked by screenshot. Physical-device feel still needs human verification.

Stacking runtime checks: **China Dress [Hard]** contains a visible two-level stack at objects 43–45; object 43 moved from x=444 to x=436.256 while source geometry remained unchanged. Accelerated autoplay remained 346/0 with 192/0 checkpoints. The old `rizu-aim-spinners-1` Zero Centimeters replay loaded with stacking disabled and preserved both its 1/91 result and exact rotation count. A screen-space injected attempt hit the three stacked circles; the new `rizu-aim-stacking-1` replay retained its 3/343 result after restarting the game.

Tracking runtime checks: China Dress autoplay retained 346/0 objects and 192/0 checkpoints with no tracking breaks. The previous stacked replay loaded with tracking disabled and preserved 3/343. An injected mouse-follow attempt released the first slider roughly 33 ms before its endpoint and still hit it, saving 1/345 with no tracking breaks. The `rizu-aim-tracking-1` replay reproduced that result after restarting the game.

Sample runtime checks: China Dress still completes with autoplay 346/0. Tick events now carry `normal-slidertick` rather than hitnormal, and the resource loader resolves the missing chart/user tick to `resources/aim/hitsounds/aim-slidertick.wav`. Headless tests cover per-edge sets/masks, changing timing-point banks/volume, first-bank naming, custom filenames, snapshot preservation, and exactly-once engine dispatch. Subjective sound balance remains unverified.

Pointer transforms at multiple sizes/UI scales are covered by headless tests; runtime screenshots were checked at 1920×1080. Audio channels loaded and advanced, but subjective audio synchronization and physical-device feel still need a human playtest. No third-party chart/audio assets were added to the repository.

The engine regression suite passes (119 tests). The broader gameplay suite also exposes two pre-existing failures in untouched `GameplayTimings_test.auto_timings_from_chart` and `ScrollSpeed_test.clamps_to_canonical_range`; both were reproduced using source/test files from HEAD. They are not fixed by this prototype.

## Future Work and Open Questions

- Review overlap/note-lock, slider tracking tolerance, spinner compatibility, and exact historical stacking rounding.
- Replace fixed bindings and the latest-only diagnostic replay UI when broader mode input/replay requirements are settled.
- Bound local replay decoding and recording memory for very long attempts; the current diagnostic store is a trusted local developer facility, not an untrusted replay import endpoint.
- Provide guaranteed built-in non-tick hitsound fallback when chart/default samples are unavailable.
- Remove or migrate historical mania-derived Aim library data only through an explicit migration; current display masks the irrelevant difficulty value.
