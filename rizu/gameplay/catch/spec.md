## Goal

Provide a playable native osu!catch prototype with deterministic derived objects, keyboard movement, dash/hyperdash, autoplay and local replay, without competitive scoring or submission.

## User Experience

- Search `1fruits` and select a native Mode=2 `.osu` chart. Use normal Play/Autoplay; modifiers and multiplayer are rejected.
- Left/Right or A/D move the catcher; either Shift enables dash. Opposite directions cancel, and physical sources are independent. The catcher is clamped to 0–512.
- Fruit/droplet catches have hit/miss counters; tiny droplets and bananas have separate extra counters. Attempts are no-fail. Completion remains on the local summary; Enter returns, R replays. The palette has **Select: Watch Local Catch Replay**.
- Primitive rendering shows the catcher, fall line, object types and hyperdash markers. No skin is needed.

## Architecture Decisions

- Native Mode=2 decoding attaches `chart.catch`, a plain source-order-derived DTO preserved through RefChart/Restorer. The existing native osu source reader and bounded slider path/timing helpers are reused; Mode=0 charts are not converted into Catch.
- Circles become fruits. Slider heads/repeats/tails become fruits, ticks become droplets; gaps are subdivided in powers of two until <=100 ms, yielding tiny droplets. Spinners generate banana showers at a similarly subdivided interval, with deterministic Park–Miller positions seeded at 1337 per chart. Generation is capped at 100000 objects. This is a prototype, not exact stable/lazer RNG/jitter compatibility.
- Catch rules are independent of Aim scoring/rules, while reusing shared clock/audio/session and queued-input-before-update scheduling. UI and interactor currently reuse the experimental summary/replay helpers with their historical Aim names; explicit Catch flags select mechanics and persistence.
- Walk/dash speeds are 500/1000 chart units per chart second. Catch half-width is `(54.4 - 4.48 * CS) * 0.8`; fall preempt follows AR. A catch tests object centre within that horizontal width at its timestamp.
- Hyperdash links successive fruits/droplets when distance exceeds dash travel plus half-width. Catching the source grants enough speed to reach the target centre before its timestamp; speed expires at the target time. Bonuses do not grant hyperdash. This simplified rule omits stable's excess-distance and direction-history details.
- Movement is evaluated from anchors reset only on action/hyperdash changes, analytically across hyperdash expiry. Extra render updates do not accumulate position error; tests require identical judgement positions for the same action timestamps across update partitions. Backward audio-clock corrections cannot integrate an interval twice. Judgements resolve strictly after object timestamps; input at that timestamp changes future velocity, not position retroactively.
- Autoplay generates ordinary dash/direction press/release events using the same rules, never pointer teleports or forced catches. Dense/impossible patterns and random banana showers may miss; perfect bonus collection is not guaranteed.
- Replay payload remains ReplayFrames/BinaryEvents. `rizu-catch-1` envelopes live in `userdata/replays/catch/<hash>_<index>.json`, separate from Aim/competitive scores. IDs 1/2/3 are arrows/left Shift; 4/5/6 are A/D/right Shift. Column 2 is paused state-only input. Recorded times use the judgement clock, with rate and offset restored on playback.
- Audio initially reuses native object head samples for fruit/droplet feedback; derived tiny droplets and bananas are silent. Empty WAV samples are intentional silence, not missing resources.

## Invariants

- Catch never creates chartplays or submits scores. Library generation skips mania difficulty for native Catch; old cache rows are not migrated.
- Source ordering and seeded generation must survive worker snapshots unchanged.
- Retry recreates catcher position, buttons, hyperdash state, events and recorder. Paused events can change held state but cannot move a frozen catcher.
- Rendering only reads state; no movement/catch logic occurs in draw.

## Verification

Headless tests cover native generation/snapshot preservation, repeat geometry, deterministic bananas, dash/bounds/independent keys, hyperdash without teleports, action replay at multiple frame rates with nonzero offset/rate, replay-mode separation and backward clock-correction regression.

Runtime checks used native **Monster (DotEXE Remix) [m1ng's Rain]**, hash `75138429ab02cd1f3a8a12ac4e1ab2aa`: 1303 derived objects. Ordinary loading/rendering and accelerated autoplay completed with 538 fruit/droplet hits and zero misses; extras were 732/33. Header-only silent WAVs in this real chart exposed a BASS length/mixer issue, fixed and tested without substituting audible samples. Injected paused direction/dash inputs did not move the catcher until resume. The saved attempt replayed after restart with matching 71/467 primary and 61/704 extra results; the initial replay discrepancy from backward audio-clock correction before the first object was fixed. No competitive result was produced. After final movement changes the saved replay and autoplay results matched again; Aim **China Dress [Hard]** completed autoplay 346/0 and button-mode **Stepper [SPN]** loaded its skin without experimental rules. Physical-device feel and exact stable compatibility remain unverified.

## Future Work and Open Questions

- Exact stable/lazer object jitter, hyperdash widths/excess carry and banana generation; richer feedback and configurable bindings.
- Broader real-chart autoplay checks and physical-device playtests.
- Extract shared experimental replay/summary plumbing from Aim-named modules once the second-mode boundary settles.
