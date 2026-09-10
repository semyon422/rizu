## Goal

Provide a playable native KSH/SDVX prototype with four BT, two FX and two independent lasers, using USC as a behavior reference rather than claiming exact commercial SDVX compatibility.

## User Experience

Native KSH charts launch through ordinary Play/Autoplay with primitive vertical BT/FX lanes, both laser paths/cursors and counters. Keys: D/F/J/K for BT, C/M for FX, W/E and O/P for lasers. Pause/retry and **Select: Watch Local SDVX Replay** reuse the experimental lifecycle; no scores are submitted. Source warnings are shown on the playfield. Real controller event binding remains pending; only explicit encoder normalization and replay payload handling are implemented.

## Architecture Decisions

- Source data is described in [../../../chart/format/ksm/spec.md](../../../chart/format/ksm/spec.md): preserve every laser anchor, beat/time, slam and extended range in ordinary note data (one note per button object or laser chain).
- `Laser` runs on a chain-anchored 240 Hz chart-time grid, with 16 Hz capture checkpoints (every 15 samples). Calls at render times do not insert extra samples. Inputs process earlier samples first; the sample exactly at an input timestamp runs after that input.
- Keyboard direction drives a normalized cursor at 2 units per chart second. Matching direction close to the target (tolerance 0.08) snaps to it, so the task is following direction rather than reproducing its exact slope speed. Wrong direction/no movement can lose tracking; moving toward the target can recover. Straight roots align automatically; captured straights stay locked without input. This is simpler than USC's time-limited assist and direction-change punishment.
- Slams require a signed turn within ±75 ms in the correct direction. Merely holding a direction before the window is not a hit. A hit moves the cursor to the destination; absent turns expire to misses. Paused turns are ignored. Exact late-slam-to-next-segment interactions remain to be tested during integration.
- `Knob` normalizes wrapped absolute encoder samples in [-1, 1] to relative movement. First sample/reset is baseline only; a delta over 1.5 wraps across the 2-unit range. Sensitivity, inversion and delta deadzone are explicit constructor parameters. Paused samples advance the baseline without movement. This is not a generic stick-velocity binding and has not been physically tested.
- `ButtonRules` uses a ±100 ms head window. Six independent lanes accept chips and explicit hold heads; repeats do not create hits. Holds must remain held through their end timestamp. Release exactly at the tail succeeds, earlier release permanently fails the hold even if repressed. Paused releases are recorded state changes and also break active holds; paused presses never hit a new head. Missing heads and tails expire strictly after their deadline, in chronological order. This binary prototype is not USC's full per-tick hold scoring.
- Input contract: IDs 1–6 are BT/FX, IDs 7/8 and 9/10 are keyboard negative/positive laser directions; all carry boolean transitions. IDs 11/12 carry relative knob displacement in `pos={delta, 0}`, with nil value. Column 1 is live, column 2 paused state-only. Keyboard defaults are D/F/J/K (BT), C/M (FX), W/E and O/P (lasers), preferring scancodes. Opposite directions cancel. `Input:axis` accepts explicitly configured encoder lanes; it does not automatically bind arbitrary joysticks. `rizu-sdvx-1` disk envelopes live in `userdata/replays/sdvx/<hash>_<index>.json`, preserve rate/offset and use existing binary ReplayFrames. Manual events record the judgement clock; paused events use column 2. The store validates channels/payloads and rejects cross-mode envelopes. Old KSH column replays are rejected explicitly.
- `Rules` combines six buttons and both lasers; it limits total chain simulation work to 2000000 fixed samples per chart. Rendering/runtime resource bounds still need profiling.
- `Rules.autoplay` generates ordinary BT/FX and laser-direction press/release events, retriggering direction edges for slams. It does not force captures or set cursor coordinates. Events are stably sorted and capped at 400000; overlapping/repeated same-time objects may still expose priority limitations.
- DSP, camera tilt/spins and decorative effects are outside this slice. Ignoring them must never alter music/note timing.

## Invariants

- Hardware-independent mechanics: playback cannot depend on a connected controller or current physical axis baselines.
- Input samples and fixed-grid state transitions, not draw/update frequency, determine capture outcomes.
- UI rendering only reads state. Extended range changes rendered path geometry, not knob normalization.
- Existing Aim, Catch and Taiko replay formats remain unchanged; native SDVX refuses legacy column-replay interpretation. Library difficulty generation skips native SDVX and existing cached difficulty is masked, without rewriting cache rows.

## Verification

Eight KSH-reader tests cover timing/geometry, including consecutive slams and extreme native timing. The reader accepts 90/90 user-provided KSH files; the selected cached 405nm(Shu※mix) [challenge] and its audio are accessible through the game filesystem. Fourteen mechanic/input/session tests cover direction/straight/reversal, loss/reacquisition, exact update-partition invariance, slam timing/paused input, encoder wrap/deadzone/inversion/reset, BT/FX hold loss/tail inclusion and binary replay of simultaneous six-button holds with both moving lasers. Runtime verification used cached **405nm(Shu※mix) [challenge]** through ordinary loading: accelerated autoplay produced 392/0 buttons, 455/0 laser checkpoints and 5/0 slams, matching headless results. Primitive rendering was inspected at 1920×1080. A partial manual attempt injected through UI key events saved 87/305 buttons, 270/185 laser checkpoints and 0/5 slams; replay after process restart matched all counters. Paused keys did not score and retry reset buttons, counters and recorder. These are accelerated/injected checks, not a physical playthrough or real controller verification. Final regressions passed: Aim China Dress 346/0, Catch Monster 538/0, Taiko T-T-Techno 535/0; Stepper 7key1scratch loaded its skin with no SDVX rules. A final unpaused SDVX autoplay again matched 392/0, 455/0 and 5/0. All 90 files also pass the full decoder; daisy cutter's `mvol=125` is preserved as 1.25 gain.

## Limitations And Next Steps

- Fixed 1.5-second visual lookahead; no scroll-speed gimmicks, DSP, camera effects or dedicated chip/slam sound assets. Audio currently plays the chart's primary music only.
- Shared historical Aim-named replay/summary helpers now route SDVX explicitly; a future cleanup can extract a common experimental session interface without changing replay formats.
- Configure joystick devices/axes explicitly, test pause/resume and real encoder behavior before claiming controller support.
- Profile large charts and compare dense slam chains/extended geometry against USC. The 90-file parser corpus is acceptance coverage, not exact compatibility proof.
- Physical-device feel and broader manual laser tracking checks remain open.
