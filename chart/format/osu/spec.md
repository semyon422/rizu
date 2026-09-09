## Goal

Preserve native osu! source data and provide deterministic, bounded slider geometry and timing for experimental Aim gameplay.

## User Experience

Circles, sliders, and spinners can be played through ordinary Aim loading, with hold/checkpoint and rotation rules, primitive rendering, autoplay, and local replay. See [../../../rizu/gameplay/aim/spec.md](../../../rizu/gameplay/aim/spec.md) for gameplay rules.

## Architecture Decisions

- `AimChart` carries source-order slider control points (including the head), curve type, declared pixel length, span count, timing points, SliderMultiplier, SliderTickRate, and format version, plus StackLeniency (default 0.7 when absent). `RefChart` carries this plain data across workers; runtime path objects are constructed separately.
- `RawOsu.format_version` preserves the decoded header for consumers. Encoding still uses the existing normalized v14 header; this is not a lossless legacy file writer.
- `SliderPath` flattens L (polyline), B (piecewise Bezier split at duplicate anchors), P (three-point circular arc, otherwise Bezier), and C (Catmull-Rom) curves. It trims or extends the final tangent to the declared pixel length, then samples by cumulative distance using binary search.
- Bezier subdivision uses a 0.5-unit second-difference tolerance and smoothed subdivided polygons; circular arcs use a 0.1-unit sagitta tolerance; Catmull-Rom uses 50 subdivisions per segment. Historical v6/v9 curve approximation quirks are not reproduced yet. These are prototype geometry rules, not a claim of exact stable compatibility.
- Paths reject non-finite coordinates, invalid lengths/types, more than 1024 controls, 16384 output points, 250000 Bezier work units, or depth beyond 32. They never silently fall back to a different curve when a budget is exceeded. A fully degenerate path has zero effective length.
- `SliderTiming` samples BPM and inherited velocity at the head. Red points reset velocity; negative beat lengths select velocity clamped to 0.1–10. With no preceding timing point it uses 500 ms and 1x velocity. Later timing points do not stretch an active slider.
- Velocity is `100 * SliderMultiplier * SV / beatLengthSeconds`. The stored osu! repeatCount is the total number of spans. Duration uses path distance, not the legacy raw `HitObject.endTime` placeholder.
- Tick spacing is `100 * SliderMultiplier * SV / SliderTickRate`; pre-v8 tick spacing omits SV. Ticks within 10 ms of the far endpoint are excluded. Reverse spans revisit the same path tick locations in reverse chronological order. Repeat and tail checkpoints are generated at exact span endpoints; current gameplay moves its runtime tail checkpoint earlier according to the Aim tracking spec. The source timing helper remains unchanged for legacy replays.

- `AimChart` additionally retains timing sample banks/volume, General SampleSet (`None` and numeric zero select the normal default bank), slider edge masks/sets, and object sample additions. `SliderSamples` resolves head/edge/tick samples during gameplay preparation and registers resources before async loading; derived checkpoint samples survive the refchart snapshot. This is additive in-memory data, not a persisted chart-format change.

## Native Taiko

Native Mode=1 decoding attaches `chart.taiko` and uses `1taiko` instead of the old `2key` metadata identifier. It preserves source-order colors, large-note flags and interval types through refchart workers. Existing library rows and competitive replays are not automatically migrated. See [../../../rizu/gameplay/taiko/spec.md](../../../rizu/gameplay/taiko/spec.md) for rules, limits, replay semantics and reindex implications.

## Invariants

- Geometry and checkpoint generation are independent of rendering and frame rate.
- Checkpoint lists are chronological and capped at 16384 entries per slider before allocation.
- Old circle-only replay files retain their circle semantics; new attempts use the tracking-versioned diagnostic envelope. Stacking shifts only runtime copies, not decoded/refchart source geometry.
- Source data survives refchart snapshots without losing repeated anchors or simultaneous objects.

## Verification

Tests cover path length trim/extension, arc direction, Bezier duplicate-anchor segmentation, curved midpoint accuracy, Catmull/degenerate paths, input/work bounds, BPM/SV sampling, reverse ticks, repeat endpoints, legacy tick spacing, and source-data refchart round trips.

## Future Work and Open Questions

- Validate geometry and timing against a broad real-chart corpus, including historical format versions and degenerate paths.
- Add looping slider/whistle audio and review exact stable sound-volume/parity behavior; edge/tick samples are now resolved separately.
