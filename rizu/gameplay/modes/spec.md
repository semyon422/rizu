## Goal

Provide minimal but playable support for four modes: **Aim (osu!standard), Catch, Taiko, and SDVX / K-Shoot Mania**.

This phase evaluates whether the existing engine can support different mechanics and gathers concrete requirements for a subsequent skinning rewrite. It does not aim for competitive compatibility with the original games.

**Status:** requirements document for the complete four-mode phase. The circle/slider Aim implementation is tracked separately in [../aim/spec.md](../aim/spec.md), including its verification status and limitations; the full phase is not complete. Current-state sections below capture the initial source investigation rather than an updated implementation inventory. Other sections describe target behavior. Proposals and unresolved questions are marked separately.

Agreed scope:
- Core mechanics and object types, not just a basic input demonstration.
- Real charts, imported and launched through the ordinary song selection menu.
- Manual play, autoplay, replay recording, and replay playback for all four modes.
- Native osu! charts only: Mode=0 for Aim, Mode=2 for Catch, Mode=1 for Taiko. Cross-mode conversions are outside this phase.
- Both keyboard and physical controller support are desirable for SDVX.
- Simple temporary graphics to discover skinning requirements, without designing the final API or rewriting the skin system yet.
- No mode-specific score formulas or score submission.
- Implementation order: **Aim → Catch → Taiko → SDVX**.

## User Experience

1. The player imports `.osu` or `.ksh` files through the existing workflow and sees the chart with its correct mode in the library.
2. They select a chart and start manual play or autoplay without a dedicated development launcher. The interface identifies experimental modes.
3. The playfield provides the essentials: objects, current input, hits/misses, and the state of sustained objects. Object types are distinguishable by more than color alone.
4. They can pause, resume, retry, and return to song selection. A new attempt does not inherit cursor state, object captures, or analog input from the previous attempt.
5. They can save and play a local replay without creating a competitive result or connecting to a server.
6. Unsupported mechanics produce clear diagnostics rather than silently converting the chart to another mode or dropping objects.

Proposal for the first phase: no-fail and a simple local summary of hits, misses, and timing errors, without ordinary chartplay records, ratings, lamps, or personal bests. Zero hits must not prevent saving a diagnostic replay.

## Scope

### Included

- Decoding the data required by core mechanics, including geometry and compound objects.
- Identifying the mode independently of button count. Taiko is not ordinary 2K, and SDVX is not a button layout with extra hold notes.
- Basic judgement based on time, position, correct button, holding/tracking, or repeated actions, depending on the object.
- Reproducible gameplay input and minimal rendering of mechanic state.
- Music, synchronization with gameplay time, and basic audio feedback.
- Library and session lifecycle integration without requiring mania difficulty or result calculation.
- Automated scenarios and a small set of real charts for manual verification of each mode.

### Excluded

- Original score/accuracy/combo/HP formulas, PP, rankings, and exact reproduction of every historical judgement quirk.
- Score submission, online leaderboards, and multiplayer for the new modes.
- Compatibility with external osu!/USC replays.
- Cross-mode conversions, editing the new mechanics, and a full set of modifiers.
- Importing external skins, final presentation, and a new skinning system.
- Full support for storyboards, camera effects, and SDVX audio DSP. These may be absent as long as the timeline and gameplay mechanics remain correct.
- Unrestricted support for every historical format version and nonstandard extension.

**No scoring does not mean no judgement.** States and events must show what the player did correctly or incorrectly. Timing windows, radii, speeds, tracking conditions, and slam rules must be explicit mechanic parameters; their exact values should be determined from references and fixed in tests. Do not automatically apply mania timings to every mode.

## Current Implementation And Gaps

| Area | Current implementation | What needs verification or change |
| --- | --- | --- |
| Session | `rizu/gameplay/GameplaySession.lua` selects manual/auto/replay; `RhythmEngine` combines timing, input, logic, visuals, and audio | Preserve the shared lifecycle while giving modes their own mechanics and state |
| Mode identity | `chart/core/InputMode.lua` describes input groups and counts | Do not treat the layout as a complete ruleset; define mode representation without silently changing existing identifiers |
| osu! | `chart/format/osu/Osu.lua` reduces objects to time, column, a double-hit flag, and sounds; `ChartDecoder.lua` creates tap/hold notes | Aim/Catch geometry does not survive this path; the large Taiko hit flag is not transferred to the resulting note. The names `1osu`/`1fruits` alone do not provide working mechanics; Taiko currently receives `2key` |
| KSH | `chart/format/ksm/Ksh.lua` reads laser positions and constructs segments; `ChartDecoder.lua` creates columns and note pairs | The decoder does not transfer `posStart`/`posEnd` into the note model; verify preservation of the complete path, laser identity, slams, and extended range, not just direction |
| Logic | `LogicNoteFactory.lua` supports tap/hold; laser and drumroll use `HoldLogicNote` | This does not implement lasers, rolls, or compound objects |
| Spatial input | `VirtualInputEvent` already has `pos`; `AimInputNote` and `CatchInputNote` scaffolding exists in `rizu/engine/input/notes/` | These types do not establish a complete device → mechanic pipeline; the current `InputBinder` transforms buttons and creates events without `pos` |
| Visuals | `VisualNoteFactory.lua` selects `ShortVisualNote`/`LongVisualNote` | Evaluate visibility scheduling for 2D objects, paths, and independent playfield state |
| Results | `RhythmEngine:hasResult()` depends on base/Normalscore; `ScoreSaver.lua` saves a replay, creates a chartplay, and initiates submission together | Replays and diagnostic attempt completion must work separately from this pipeline; do not bypass the existing validity check for ordinary results |
| Library | Selection no longer implicitly hides non-mania input modes | Visibility does not imply gameplay support; unsupported charts must report a loading diagnostic |
| Loading | `GameplayChart.lua` passes through compute/refchart; `RhythmEngineLoader.lua` requires chartdiff and applies existing timing/scoring settings | Verify that new data survives the entire path, not just decoding; do not replace unavailable difficulty with a fabricated mania value |

These observations do not prove that the engine needs replacement. Prototypes should reveal which shared parts can be reused and which need extraction or changes.

## Mode Requirements

### 1. Aim / osu!standard

**Source:** `.osu`, Mode=0.

- A playfield in chart coordinates, with window-size-independent conversion to and from screen coordinates.
- Mouse/absolute-pointer aiming and two gameplay buttons; presses check cursor position and time, while movement without a press must not hit a circle by itself.
- Circles: position, size, hit time, early/late misses, and clear object ordering.
- Sliders: path geometry, duration accounting for timing points/SV, repeats, initial hit, tracking, checkpoints, and completion. A slider cannot be replaced with a single-column hold note.
- Explicit support and tests for the basic `.osu` curve types; path length and movement speed must not depend on frame rate.
- Spinners: active interval, cursor rotation, accumulated progress, and completion condition. The original rotation score formula is not required.
- CS/AR/OD and stacking data must not be silently discarded. Basic object size, appearance timing, and placement are necessary for readable real charts; exact historical compatibility requires a separate decision.
- Temporary visuals: circle/approach indicator, slider path and moving point, tracking area, spinner center and progress, cursor, and feedback.

**Engine capabilities under evaluation:** spatial hit-testing; multiple candidates under the cursor; button state independent of movement; compound objects with events inside an interval; separate appearance and judgement timing.

### 2. Catch

**Source:** `.osu`, Mode=2. Shared slider path and timing calculations should preferably be reused from Aim; this does not mean converting Mode=0 charts in the library.

- Catcher movement left/right, stopping, dash, and playfield boundaries.
- Fruits, droplets, and tiny droplets from sliders; bananas from spinners. Derived objects have defined positions and catch times, with reproducible generation.
- Catching by horizontal overlap at the instant an object crosses the catcher line, not by a button press near the note time.
- Hyperdash: identify transitions that require it, activate and end acceleration, and show a visible marker. Verify that the transition is playable, not merely that a flag exists.
- Fix catcher speed, catch area size, falling time, and dash parameters. Random sequences need a recorded seed or another deterministic generation method.
- Temporary visuals: catcher, catch line, falling objects, distinct object types, dash/hyperdash state, and misses.

**Engine capabilities under evaluation:** continuous player state outside individual notes; automatic spatial judgement without a new press; events between frames; consistency between object generation and replay.

### 3. Taiko

**Source:** `.osu`, Mode=1.

- Four logical actions: left/right don and left/right kat; shared color must not erase hand identity.
- Ordinary don/kat: correct hit type and timing; a wrong-color hit does not count as correct.
- Large notes: distinguish a single hit from a coordinated double hit, including events in different frames within the second-hit window. One button must not represent two hands. No bonus score formula is required.
- Drumrolls: repeated hits during an interval, progress, and completion; not a single held button.
- Spinners: repeated actions with a basic don/kat alternation rule and completion threshold, without original score bonuses.
- Temporary visuals: horizontal track, hit area, distinct don/kat and large notes, roll bodies, spinner progress, and indicators for all four actions.

**Engine capabilities under evaluation:** multiple input sources for one object; repeated event consumption by a compound object; priority rules between rolls/spinners and neighboring notes.

### 4. SDVX / K-Shoot Mania

**Source:** `.ksh`. The behavior reference is unnamed-sdvx-clone (USC); exact compatibility with commercial SDVX is not claimed.

- Four BT and two FX buttons: chip/tap and hold objects with clear start, holding, loss, and completion handling.
- Two independent lasers: segment position and direction, straight and sloped sections, direction changes, chain start/end, slams, and extended range.
- A laser cannot be replaced with a sequence of button hold notes. It requires analog cursor and path-tracking state, loss/reacquisition, and a timed slam condition.
- Keyboard: two direction pairs translated into virtual knob control.
- Controller: two independent relative-motion channels; account for how the device exposes encoders, wrapping axes, sensitivity, inversion, and deadzone. No specific device has been selected yet.
- Keyboard and controller must converge on shared virtual input, but need not use identical hardware processing. Replays must not depend on a connected controller.
- Define tracking, tolerances, and straight-section behavior from the reference. USC uses relative motion and tracking assistance; naive absolute aiming is not equivalent mechanics.
- Temporary visuals: BT/FX lanes, hold objects, both laser paths, current and target cursor positions, slams, and capture state. A flat playfield is acceptable; perspective is optional.
- FX/DSP, camera tilt/rotation, and decorative effects may be omitted. Ignored effects must not shift music timing or alter gameplay paths.

**Engine capabilities under evaluation:** independent continuous channels, mixed button/analog input, segment interpolation and instantaneous transitions, and movement playback without hardware.

## Replay And Autoplay Requirements

### Current Format Capabilities

Pipeline: `VirtualInputEvent` → `ReplayRecorder` → `ReplayFrames` → `BinaryEvents`; playback uses `ReplayPlayer`. The outer envelope uses `ReplayFactory` and `sea/replays/ReplayCoder.lua`.

- An event contains `f64` time, a `u8` ID, a `nil/false/true/left/right` value, an optional column (1–127), and an optional pair of `f64` coordinates.
- It can represent button events and position samples, including movement without a press. Array order is preserved; identical timestamps do not imply merging events into one simultaneous event.
- `ReplayFrames` compresses the stream; `ReplayFactory` creates a version=2 envelope. The public `VirtualInputEvent` contract requires a column even though the binary codec supports its absence.
- `ReplayPlayer` advances the engine to each event time, supplies input, then advances to the current update time. This is a useful foundation, but does not by itself guarantee FPS-independent continuous simulation.
- `ReplayRecorder` stores an event reference: reusing or mutating the event object or its `pos` table after recording requires an explicit decision.
- The current `AutoplayPlayer` generates column presses/releases. It does not yet construct spatial or analog actions.

**Preliminary conclusion:** the existing event container is a plausible fit for all four modes. There is no reason to introduce a new binary format in advance. However, payload expressiveness is not a complete input, recording, and deterministic playback contract.

### Required Investigation Before Extending The Format

1. Define the semantics of `id`, `column`, `value`, and `pos` for each mode. Check stable cursor/analog-channel IDs and the `u8` limit, not just IDs for temporarily pressed buttons.
2. For Aim, record absolute chart-space position separately from button transitions; test movement with and without held buttons, position at click time, and multiple buttons sharing one cursor.
3. For Catch, compare recording left/right/dash actions with deterministic integration against recording catcher state. In osu! lazer, the replay contains catcher position and dash, and playback interpolates position; this does not prove that button transitions alone suffice. Decide and document whether replay tests the movement simulation itself or reproduces an already computed trajectory. Catcher position must not depend on playback FPS.
4. For Taiko, preserve all four actions, same-time event ordering, and the second hit of a large note, not just the color index.
5. For SDVX, compare relative increments against accumulated virtual-knob state represented through `pos`. Choose one explicitly documented contract; do not mix relative and absolute values without identifying their semantics.
6. Define behavior between samples: hold the last value, interpolate, or integrate. Judgement and visual smoothing must not accidentally determine each other's behavior.
7. Fix the time scale and apply input offset/rate exactly once; check identical timestamps, pauses, and interval-boundary events.
8. Check the replay envelope: chart and mode identity, mechanic version, judgement parameters, seed, and other simulation inputs. Playback must not depend on current user settings.
9. Measure sample frequency, long-replay size, and recording memory. Check validator limits, including frame count; do not discard samples in ways that change mechanics.
10. If recording downsamples movement, compare it against the full manual-input stream: fast reversals, brief exits from the tracking area, and spinner rotation. Force significant state samples at button transitions and other mechanic boundaries, or prove another sufficient method. Identical playback at different FPS does not yet prove that replay matches the original manual attempt.
11. Check the ordering of “advance simulation → apply event → resolve coincident object boundaries.” Choose explicit interval handling (event boundaries, substeps, or a combination) so a long frame cannot skip important states.

If the existing format really is insufficient, first document the specific scenario it cannot represent. Then separately agree on versioning and backward reading of old replays; do not silently redefine existing fields. The server protocol does not automatically expand with the experiment.

### Replay And Autoplay Acceptance Criteria

- Record a manual attempt, serialize it, load it, and play it back: judgement events, their order, and significant states match; allowed numerical tolerance is explicit.
- Test one stream at 30/60/144 FPS, with irregular frames and a long frame crossing multiple events. Separately test supported rate changes and nonzero input offset.
- Continuous objects are handled correctly even when multiple checkpoints, a direction change, or a slam occur between two frames.
- Autoplay generates valid virtual input through the same mechanics rather than directly marking objects as hit. Its stream can serve as a reproducible test.
- Pausing does not accumulate hidden movement or cause an analog-input jump on resume. Retry creates a new session; backward seeking is not assumed to work without state restoration.
- Diagnostic replay saving/loading is separate from `ScoreSaver` and does not submit scores or create ordinary results.

## Architecture Decisions

### Shared Session, Separate Mechanic Rules

Preserve existing session, timing, resource, and audio boundaries as far as prototypes justify. Mode-specific rules must not spread through the shared timer and song selection screen. This document does not fix new class names or interfaces.

### Judgement Separate From Score Calculation

Mechanics report hits, misses, capture, loss, and object progress without requiring a particular scoring system. Experimental completion/replay policy must not weaken `RhythmEngine:hasResult()` for existing modes or use fabricated Normalscore values to pass its checks.

### Data Sufficiency Before Rendering

Verify the entire pipeline for each mechanic: source file → decoder → chart/compute/refchart → session loading → logic and visuals. Arbitrary `Note.data` does not guarantee that data survives transformations, sorting, note linking, and transfers between threads.

Any persistence, mode identifier, or import cache changes must be explicit, with reindexing/compatibility rules. Existing osu!mania and KSH transformations must not change silently.

### Temporary Rendering As An Investigation Tool

Existing UI components and resource loading may be reused. Starting a mode must not require a finished user skin. Primitives, a built-in font, and simple indicators are sufficient.

During implementation, collect the following for future skinning work:
- playfield coordinate space and pointer transformations;
- geometry of objects, links, and compound parts;
- appearance timing, activity, progress, and judgement state;
- player state: cursor, catcher, buttons, and laser cursors;
- layer order, clipping, and static/dynamic geometry;
- events suitable for animation and sound;
- update frequency and data preparation cost.

The deliverable is a list of actual data requirements and constraints, **not a universal skin API**. Rendering must not determine hit outcomes, move the catcher, or simulate gameplay from `draw()`.

### Use References For Specific Tasks

- `rizu_webclient` is the closest compact reference for the initial Aim prototype: input, geometry, object state, autoplay, and isolated tests.
- `ppy/osu` (lazer) provides references for object composition, mode components, replay timing, and edge cases; it is not a template for transplanting its entire UI hierarchy into our engine.
- Local legacy osu! provides an additional check of stable behavior. Lazer and stable are not interchangeable rule sources: choose target behavior and a test for each discrepancy rather than silently mixing their timings and judgement.
- USC is the reference for KSH, keyboard/hardware knobs, and laser tracking.

Geometry proposal: compute a canonical slider path once and reuse it in mechanics, autoplay, and rendering; build the visual mesh separately. Bound approximation complexity and the number of derived objects. If a limit is exceeded, explicitly diagnose the unsupported object rather than silently substituting different geometry. This is a useful shared contract for Aim and Catch, not a requirement for particular classes.

The inspected projects do not prove that our replay or engine is ready: their algorithms and test scenarios must be adapted to our invariants.

## Invariants

- One attempt means one fresh session. Retry carries no previous-attempt state.
- Logical time, not rendered frame count, determines movement and judgement.
- Manual play, autoplay, and replay use the same mechanics and attempt parameters.
- Gameplay input coordinates are independent of resolution, DPI, and playfield presentation.
- Losing an object's type or geometry must not leave the chart appearing fully supported. Optional decoration may be ignored; unsupported gameplay mechanics must be diagnosed, and the chart must not be presented as verified.
- Experimental attempts are not submitted, even when the client is online and diagnostic metrics resemble a valid score.
- New modes do not change existing button-mode mechanics, result saving, or replay reading.
- Synthetic events alone do not verify controller support: separate hardware testing is required.

## Verification And Delivery

### Shared Preparation

- Select charts and small synthetic scenarios for every core object type. Real files verify import; synthetic scenarios verify precise mechanic boundaries.
- Record each chart's origin, hash, mode, tested mechanics, and expected limitations. Do not include third-party music/resources in the repository without appropriate permission.
- Verify the lifecycle without scoring/submission and the separation of local replays.
- Test the replay contract with button, positional, and two-channel continuous input before declaring it sufficient.

### For Each Mode, In The Agreed Order

1. Data and import: every required mechanic is represented without loss on the way to the session.
2. Logic and input: positive/negative scenarios and time/position boundaries.
3. Manual play with temporary visuals through the ordinary menu.
4. Autoplay, recording, and playback; verify frame independence.
5. Pause/resume/retry/exit, with explicit verification that ordinary score saving and network submission do not occur.
6. A short report: reused components, required changes, engine constraints, and data needed by future skins.

**Minimum scenarios:** Aim — spatial circle miss, overlapping objects, slider repeat and tracking loss, rotation across the angle wrap boundary; Catch — catching between frames, playfield edge, dash/hyperdash, and droplet streams; Taiko — wrong color, two hands in different frames, repeated roll hits, and spinner alternation; SDVX — simultaneous BT/FX and both lasers, reversal, straight section, slam, loss/reacquisition, and a wrapping controller axis.

**Phase completion criterion:** all four modes pass the end-to-end workflow on an agreed set of real charts; replays reproduce mechanics; there is no submission or regression in existing gameplay; an evidence-based conclusion documents engine suitability and skinning requirements. An untested controller or missing core object type remains an explicit incomplete item.

At the time of investigation, `./test rizu/engine/replay` passes (3 tests), but covers the codec and sequential event delivery rather than end-to-end simulation of the four modes.

## References

### Local osu!

Found at `../osu-master`. This is a legacy tree with separate ruleset and hit object implementations; its exact snapshot version/date is unconfirmed (the directory has no Git metadata). Do not automatically treat it as a verified 2016 release.

Useful locations within that tree:
- `osu!/GameModes/Play/Rulesets/Osu/`, `Fruits/`, `Taiko/` — mode rules.
- `osu!/GameplayElements/HitObjects/Osu/SliderOsu.cs`, `SpinnerOsu.cs` — compound Aim objects.
- `osu!/GameplayElements/HitObjects/Fruits/HitFactoryFruits.cs`, `SliderFruits.cs`, `SpinnerFruits.cs` — Catch object generation.
- `osu!/GameModes/Play/Rulesets/Fruits/RulesetFruits.cs` — movement and dash/hyperdash.
- `osu!/GameplayElements/HitObjects/Taiko/HitCircleTaiko.cs`, `SliderTaiko.cs`, `SpinnerTaiko.cs` — large notes, rolls, and spinners. In particular, a large hit can arrive as two events in separate updates.

### Unnamed SDVX Clone

Repository: <https://github.com/Drewol/unnamed-sdvx-clone>.

The investigation used snapshot `260b050569413a04db9d437c5158d2a032873ad6`:
- `Main/src/Input.cpp`, `Main/include/Input.hpp` — keyboard, relative input, sensitivity, and wrapping controller axes.
- `Main/src/Scoring.cpp`, especially `m_UpdateLasers` — actual laser tracking mechanics, not just score calculation.
- `Beatmap/src/BeatmapFromKSH.cpp` — segments, slams, and extended range.
- `Main/src/Replay.cpp` — an additional reference, not our replay contract. Laser playback in the inspected `Scoring.cpp` also uses judgement data; this is not proof of deterministic raw-input playback.

### Rizu Webclient

Repository: <https://github.com/Nimue-lua/rizu_webclient>, inspected snapshot [`30ff51683c0b35e8aba92483d40043c0b7c46666`](https://github.com/Nimue-lua/rizu_webclient/tree/30ff51683c0b35e8aba92483d40043c0b7c46666).

The inspected session factory explicitly supports **mania and osu**, not all four target modes. For Aim, this is a more compact implementation reference than the full osu! client.

| Source in this snapshot | Useful contract |
| --- | --- |
| [`src/gameplay/createGameplaySession.ts`](https://github.com/Nimue-lua/rizu_webclient/blob/30ff51683c0b35e8aba92483d40043c0b7c46666/src/gameplay/createGameplaySession.ts) | Runtime selection by mode; chart/replay mode compatibility checks; autoplay supplied as a playback replay |
| [`src/gameplay/osu/OsuInputEvent.ts`](https://github.com/Nimue-lua/rizu_webclient/blob/30ff51683c0b35e8aba92483d40043c0b7c46666/src/gameplay/osu/OsuInputEvent.ts), `OsuGameplayRuntime.ts` | Separate timestamped aim/action events; action state aggregated across sources, so releasing the mouse does not release a still-held keyboard action |
| [`src/gameplay/osu/OsuSliderPath.ts`](https://github.com/Nimue-lua/rizu_webclient/blob/30ff51683c0b35e8aba92483d40043c0b7c46666/src/gameplay/osu/OsuSliderPath.ts) | Curve approximation, cumulative length table, position lookup by distance, and work/point-count limits |
| [`src/gameplay/osu/OsuRulesEngine.ts`](https://github.com/Nimue-lua/rizu_webclient/blob/30ff51683c0b35e8aba92483d40043c0b7c46666/src/gameplay/osu/OsuRulesEngine.ts) | Logic without DOM/WebGL: spatial hit-testing, note lock, slider head/ticks/repeats/tail, and spinner rotation; exposes states and judgement events |
| [`src/gameplay/AutoplayReplay.ts`](https://github.com/Nimue-lua/rizu_webclient/blob/30ff51683c0b35e8aba92483d40043c0b7c46666/src/gameplay/AutoplayReplay.ts) | Aim and action generation for circles, sliders, and spinners with explicit same-time event ordering |
| [`tests/OsuRulesEngine.test.ts`](https://github.com/Nimue-lua/rizu_webclient/blob/30ff51683c0b35e8aba92483d40043c0b7c46666/tests/OsuRulesEngine.test.ts), `tests/OsuGameplayRuntime.test.ts` | Concrete scenarios: radius/timing boundaries, overlapping circles, tracking loss, multiple button sources, recording between frames, and replay interpolation |

Adaptation caveats:
- `OsuRulesEngine` already creates a score engine and contains some presentation data. Its algorithms and testability are useful, but mechanics need not depend on scores or animation parameters in our implementation.
- The runtime sends every aim sample to manual-play mechanics, but records the latest pending sample at roughly a 60 Hz limit; it forcibly saves pending aim before an action. Playback linearly interpolates recorded positions and supplies them to mechanics too. Losing brief movement during recording is therefore a separate risk for our reproducibility checks.
- Replays quantize time and coordinates with a factor of 8192, use separate mode-specific types, and store judgement events. This is a different format, not a reason to change our `BinaryEvents` or treat stored judgements as authoritative instead of recalculating them.
- When path construction exceeds its budget, `OsuSliderPath` returns a simplified path with `degraded=true`. Our prototype must diagnose this explicitly; a safe fallback does not establish geometric compatibility.
- `LICENSE` contains GPLv3. Check terms and license compatibility separately before porting fragments; studying the architecture does not imply copying code.

### osu! lazer (`ppy/osu`)

Repository: <https://github.com/ppy/osu>, inspected snapshot [`a14ad5f7088acd5035961c8ea8cd0935aa0c1967`](https://github.com/ppy/osu/tree/a14ad5f7088acd5035961c8ea8cd0935aa0c1967). This is modern lazer, not the local legacy snapshot.

| Source in this snapshot | Useful contract |
| --- | --- |
| [`osu.Game/Rulesets/Ruleset.cs`](https://github.com/ppy/osu/blob/a14ad5f7088acd5035961c8ea8cd0935aa0c1967/osu.Game/Rulesets/Ruleset.cs) | A mode separately creates its converter, processor, drawable ruleset, score/health, and other components. The useful part for our minimum is responsibility separation, not the full factory set |
| [`osu.Game.Rulesets.Osu/Objects/Slider.cs`](https://github.com/ppy/osu/blob/a14ad5f7088acd5035961c8ea8cd0935aa0c1967/osu.Game.Rulesets.Osu/Objects/Slider.cs) | A slider generates nested head/tick/repeat/tail objects with times and positions. Path geometry and interval events are not reducible to two hold endpoints |
| [`osu.Game.Rulesets.Catch/Beatmaps/CatchBeatmapProcessor.cs`](https://github.com/ppy/osu/blob/a14ad5f7088acd5035961c8ea8cd0935aa0c1967/osu.Game.Rulesets.Catch/Beatmaps/CatchBeatmapProcessor.cs) | Postprocessing derived objects, deterministic randomness, and hyperdash links. The code explicitly documents stable-compatible width and timing quirks |
| [`osu.Game/Rulesets/UI/ReplayRecorder.cs`](https://github.com/ppy/osu/blob/a14ad5f7088acd5035961c8ea8cd0935aa0c1967/osu.Game/Rulesets/UI/ReplayRecorder.cs), `DrawableRuleset.cs` | Periodic samples at 60 Hz by default, mandatory frames on presses/releases; the drawable ruleset also requests a frame on judgement. Screen coordinates are converted to playfield coordinates |
| [`osu.Game.Rulesets.Catch/UI/CatchReplayRecorder.cs`](https://github.com/ppy/osu/blob/a14ad5f7088acd5035961c8ea8cd0935aa0c1967/osu.Game.Rulesets.Catch/UI/CatchReplayRecorder.cs), `osu.Game.Rulesets.Catch/Replays/CatchReplayFrame.cs` | Records time, **catcher position**, and dash; movement actions are also derived from neighboring positions. This replays movement state, not just raw keys |
| [`osu.Game.Rulesets.Osu/Replays/OsuFramedReplayInputHandler.cs`](https://github.com/ppy/osu/blob/a14ad5f7088acd5035961c8ea8cd0935aa0c1967/osu.Game.Rulesets.Osu/Replays/OsuFramedReplayInputHandler.cs), `osu.Game.Rulesets.Catch/Replays/CatchFramedReplayInputHandler.cs` | Position interpolation and reconstruction of mode input. Catch supplies `CatcherX`; Aim supplies pointer position and a set of pressed actions |
| [`osu.Game.Rulesets.Taiko/Replays/TaikoReplayFrame.cs`](https://github.com/ppy/osu/blob/a14ad5f7088acd5035961c8ea8cd0935aa0c1967/osu.Game.Rulesets.Taiko/Replays/TaikoReplayFrame.cs) | Four independent actions: Left/Right Centre/Rim, without reducing two hands to one color |
| [`osu.Game/Rulesets/UI/FrameStabilityContainer.cs`](https://github.com/ppy/osu/blob/a14ad5f7088acd5035961c8ea8cd0935aa0c1967/osu.Game/Rulesets/UI/FrameStabilityContainer.cs), `osu.Game/Rulesets/Replays/FramedReplayInputHandler.cs` | Substeps across large time gaps, alignment with replay-frame boundaries, catch-up limits, and special handling of important frames. Coordinate interpolation alone does not solve playback |
| [`osu.Game/Skinning/SkinnableDrawable.cs`](https://github.com/ppy/osu/blob/a14ad5f7088acd5035961c8ea8cd0935aa0c1967/osu.Game/Skinning/SkinnableDrawable.cs) | Visual component replacement through skin lookup, with a built-in implementation when a resource is absent. A useful reference for optional user skins, not a ready-made API to port |

Adaptation caveats:
- Lazer is not a headless example of fully separating mechanics from visuals: for example, `osu.Game.Rulesets.Osu/Objects/Drawables/DrawableSlider.cs` performs `CheckForResult` and tracking updates in the drawable lifecycle. This is not calculation from `draw()`, but it still depends on the UI update tree. Our judgement must remain testable independently of presentation.
- `FrameStabilityContainer` does not magically guarantee complete determinism. Explicit substeps, exact replay boundaries, and a catch-up update budget are useful; its specific frequencies and UI container need not be copied.
- `ClassicSliderBehaviour` and the stable caveats in Catch show that one project can contain different rule variants. Our tests must identify the chosen mechanic variant.
- Scenarios for later adaptation: `osu.Game.Rulesets.Catch.Tests/TestSceneReplayRecording.cs` checks movement to the edges and dash in replays; `TestSceneCatchReplayHandling.cs` checks that manual input cannot interfere while a replay is attached and that control returns after detaching it. These are not raw-input determinism tests.
- The root `LICENCE` is MIT; required notices must be preserved when porting code, and resource/dependency provenance must be checked separately.

The additional references were investigated through source code and selected tests; their applications and test suites were not run during this investigation. Neither replaces USC as an SDVX reference.

Use external projects to study behavior. Before transferring code or resources, separately verify their license and provenance; this document does not assume implementation copying.

## Future Work and Open Questions

- Approve the no-fail and local diagnostic summary proposal without chartplay; define minimal replay saving/playback UI.
- Select a specific SDVX controller and collect sample events. The keyboard path can be implemented first, but hardware support cannot be declared complete without testing.
- Fix initial timings, sizes, speeds, stacking rules, Taiko spinner rules, and laser assist. Simplifications must be named rather than hidden behind a promise of full compatibility.
- Choose mode and parameter representation independently of input layout; assess effects on metadata, filters, caches, and previously imported charts.
- Prove that the current replay is sufficient and define reproducible continuous-input handling. Decide on a new format only after this investigation.
- Select reference charts and acceptable frame-time, memory, and replay-size limits; measure them on specified hardware rather than claiming unverified performance.
- After prototyping, decide which changes extend the current engine and which require reworking shared subsystems. Then use the findings for a separate skinning design effort.
