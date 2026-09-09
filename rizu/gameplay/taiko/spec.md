## Goal

Implement a native Mode=1 Taiko prototype, preserving four actions and compound objects without competitive scoring.

## User Experience

Controls: F/J for left/right don and D/K for left/right kat. A horizontal primitive track shows note color, large notes, roll bodies, spinner progress and four button indicators. Ordinary Play, Autoplay, pause/retry and **Select: Watch Local Taiko Replay** reuse the experimental lifecycle. Correct single-hand large notes count as hits with a separate Single counter; coordinated pairs increase Double. Rolls/spinners complete on reaching the target, with further bonus hits ignored in this prototype.

## Architecture Decisions

- `chart.osu.TaikoChart` reads native Mode=1 data directly. It retains simultaneous source-order notes, sound-mask color (whistle/clap = kat), finish-mask size, rolls and spinners. No Mode=0 conversion.
- Roll duration uses declared slider length, spans and head-time BPM/SV from `SliderTiming`; spatial curves are irrelevant. Target counts are prototype-only: roll `ceil(duration * 4)`, spinner `ceil(duration * (3 + 0.3 * OD))`, minimum one. No claim of exact stable/lazer roll tick or spinner requirement compatibility.
- Ordinary hit window is ±(120 - 8 * OD) ms. Wrong color consumes the earliest eligible note as a miss. No accuracy score is generated.
- Large notes accept a same-color second hand within 30 ms of the first hit, while the first remains held. Repeated keydown is not a second hand. A lone correct hit becomes `single`, not a miss; a paired hit becomes `double`. Endpoint inclusion is explicit and need not match stable's strict inequality.
- Repeated press edges advance rolls. Spinners accept alternating don/kat colors, starting with either; duplicate colors are ignored without stable's invalid-input cooldown. One event affects one object. Pending second hands have priority, then ordinary notes, then the earliest active interval.
- Deadlines are resolved chronologically and strictly after the boundary. Paused/column-2 transitions update held state without hits. Autoplay emits ordinary ordered press/release events; overlapping objects may prevent perfect autoplay under the priority rules.
- Limits: 100000 source objects, 10000 required actions per interval, and 200000 generated autoplay press/release actions per chart.
- Mode identity changes for newly decoded native Taiko from legacy `2key` to `1taiko`. `chart.taiko` survives RefChart workers independently of column-note collisions. Old library rows are not silently migrated: they remain searchable as `2key`, but ordinary loading re-decodes the source and uses Taiko rules. Reimport/reindex is needed for `1taiko` search and the experimental label. Legacy 2K competitive replays are not a Taiko replay format and are not migrated.
- The shared experimental plumbing retains historical Aim names; Taiko selects its own input/rules/store. `rizu-taiko-1` envelopes live in `userdata/replays/taiko/<hash>_<index>.json`, with rate and input offset, using the existing binary action payload. Stores reject cross-mode envelopes, positions and non-boolean action values. Column 1 is live input, column 2 paused state-only. No persistence or remote protocol format for competitive scores changes.
- Native Taiko skips mania difficulty generation and rejects modifiers/reordering, multiplayer and competitive score saving. Supported playback rates are 0.25x–4x. Audio uses resolved chart object samples; no skin or new sound assets are required.

## Invariants

- Four distinct IDs (1/2 don, 3/4 kat) preserve hand identity through replay.
- Rendering does not advance rules. Judgement events are invariant to update partitioning for identical timestamped inputs.
- No competitive result or submission is enabled. Existing Aim/Catch replay envelopes retain their contracts.

## Verification

Headless tests cover native decoding, simultaneous objects, roll BPM/SV duration, worker/refchart preservation, invalid source rejection, wrong colors, second hands across updates, released/late second hands, repeated-key rejection, roll edges, spinner alternation, paused state, replay isolation, no-score guards and autoplay/replay update partitions at nonzero offset and 1.5x rate.

Runtime checks used native **T-T-Techno [Muzukashii]** (`8a1e02a17f6473f029596cbc4a0cc0b7`, index 1): autoplay 535/0, 37 doubles, one completed spinner; and **China Dress [Shiro's Muzukashii]** (`bd2ea911463a77ad9e6e97132d67e0a6`, index 1): autoplay 452/0, 41 doubles, two completed rolls. Primitive rendering was inspected at 1920×1080. Injected ordinary UI key events 20 ms apart produced one double hit; the saved manual attempt replayed after process restart with identical 1/451 and one double. Timeline completion was accelerated, not a full physical-device playthrough. Runtime paused F/J presses produced no hits; retry cleared buttons, counters and recorder. Regression checks after restart: Aim China Dress autoplay 346/0, Catch Monster autoplay 538/0, and Stepper 7key1scratch loaded its skin without Taiko rules. Physical feel, exact historical timing/SV behavior and dense overlapping autoplay remain unverified.

## Future Work and Open Questions

- Native Taiko scrolling BPM/SV and exact historical roll duration/density rules; current rendering uses a fixed 1.5-second lookahead, and duration uses shared slider timing without stable-specific factors.
- Configurable keys, drum-specific hitsound fallback, score-free hit feedback, interval bonuses after completion.
- Extract generic experimental orchestration from Aim-named helpers, and make library mode migration an explicit separate workflow.
