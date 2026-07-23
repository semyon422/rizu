# Score 34438 Automap Memory Exhaustion

## Status

Confirmed on 2026-07-23. This issue is not fixed.

Score `34438` still exhausts the current LuaJIT process memory limit while
recomputing its chart and replay.

## Historical Data

The production snapshot used for the investigation is located at:

```text
../rizu-backup/soundsphere-updater/server-master/
```

The relevant records and files are:

| Data | Value |
|---|---|
| Chartplay ID | `34438` |
| Chart hash | `ccfa2ddcb3467481368f210ea92f4c8b` |
| Chart name | `New Wave Bossanova.mid` |
| Chart storage size | 1,265 bytes |
| Parsed input mode | `88key` |
| Replay hash | `61b16aed7026f729830158ea6ea2b170` |
| Replay storage size | 1,398 bytes |
| Replay frames | 222 |
| Replay modifiers | `NoLongNote`, Automap to `24key` |

The database record has `compute_state = "invalid"` and was last recomputed
on 2025-05-29.

## Reproduction Result

Loading the replay and parsing the MIDI chart succeeds. Resident memory is
approximately 14 MB after those steps.

The failure occurs during `ComputeContext:computeBase()`, while applying the
Automap modifier. With the repository's 2 GB LuaJIT memory limit, the process
terminates with:

```text
luajit: not enough memory
```

The failure occurs before difficulty or replay computation completes.

## Root Cause

Automap converts the chart from 88 keys to 24 keys through
`Automap:processReductor()`. The reduction pipeline calls
`LineBalancer:process()`.

`LineBalancer` eagerly constructs column combinations for every chord size
from 1 through the target key count:

```lua
for noteCount = 1, self.targetMode do
	-- Generate every combination of target columns of this size.
end
```

It then constructs a second `targetMode`-element map for every generated
combination. For a 24-key target this creates:

- `2^24 - 1`, or 16,777,215, combination tables;
- 201,326,592 entries across the combination tables;
- 402,653,160 entries across the corresponding 24-element maps;
- additional outer tables and allocator overhead while both representations
  remain alive.

This exponential allocation explains the historical report of more than
8 GB of memory use.

The allocation depends mainly on the Automap target key count, not on the
size of the source chart. A small chart can therefore trigger it.

## Confirming Experiment

This chart has 75 note lines. After note-count reduction, only the following
chord sizes are needed:

| Reduced chord size | Lines |
|---:|---:|
| 1 | 57 |
| 2 | 14 |
| 3 | 2 |
| 4 | 2 |

A runtime-only diagnostic replacement generated combinations only for chord
sizes actually used by those lines. It generated 12,950 combinations instead
of 16,777,215.

With that diagnostic change, the complete modifier, difficulty, and replay
computation succeeded:

- peak resident memory was approximately 36 MB;
- output chart mode was `24key`;
- output chart contained 99 notes and 99 judges;
- the replay computation completed in under one second.

No diagnostic changes were saved to the repository.

## Risk

Automap currently accepts target key counts from 1 through 26. Any reduction
to a sufficiently high target key count can cause the same exponential
allocation. This affects both local computation and server-side chartplay
recomputation when such a replay is accepted.

There is currently no focused test coverage for `LineBalancer`, `Reductor`,
or a high-key end-to-end Automap reduction.

## Future Fix

The preferred direction is to stop eagerly generating combinations for every
chord size.

Possible implementations:

1. Determine the distinct `reducedNoteCount` values present in the input
   lines and generate combinations only for those sizes.
2. Generate and cache combinations lazily when a chord size is first used.
3. Avoid storing both the column-list and full-width map representations when
   one representation can be derived cheaply.

The first option is already supported by the confirming experiment and is
the smallest likely change. The algorithm's output must still be compared
with the current implementation for target modes small enough to run safely.

Defense-in-depth limits on Automap target modes or estimated combination
counts may also be useful, especially for server-side computation, but should
not replace fixing the eager allocation.

## Verification Needed for the Fix

- Add focused `LineBalancer` tests covering only the chord sizes present in
  the supplied lines.
- Add an end-to-end 88-key to 24-key Automap reduction regression test using
  a small synthetic chart.
- Compare results against the existing implementation for practical target
  modes to ensure column selection behavior is unchanged.
- Run the historical score through `ReplayLoader` and `ComputeContext` when
  the backup corpus is available.
- Measure peak memory and ensure it scales with used chord sizes rather than
  `2^targetMode`.
- Verify invalid or adversarial replay modifier values fail without large
  allocations.

## Relevant Code

- `sphere/models/ModifierModel/Automap.lua`
- `chart/transform/Reductor.lua`
- `chart/transform/LineBalancer.lua`
- `sea/compute/ComputeContext.lua`
- `sea/compute/ChartsComputer.lua`
- `sea/replays/ReplayLoader.lua`
