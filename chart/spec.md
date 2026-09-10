# Chart (`chart/`)

## Goal

Consolidate chart-related infrastructure — data model, format parsers, scoring, and transformation — under a single `chart/` namespace, replacing the scattered `ncdk/`, `chartbase/`, and `libchart/` directories.

## User Experience

- All chart types, decoders, encoders, and scoring modules are reachable from `chart.*`.
- Class names drop redundant directory prefixes (e.g. `ncdk2.Chart` → `chart.Chart`).
- Format-specific modules keep their format name in the path (e.g. `chart.format.sph.ChartDecoder`).

## Modules

| Subfolder | Source | Role |
|---|---|---|
| `chart/core/` | `ncdk/ncdk/` | Low-level types: `Fraction`, `InputMode`, `Resources` |
| `chart/model/` | `ncdk/ncdk2/` | Chart data model: `Chart`, notes, layers, compute, convert, timing points, visual |
| `chart/chartedit/` | `ncdk/chartedit/` | Editor abstractions: `Layer`, `Notes`, `Converter`, `Visual`, `Measures` |
| `chart/refchart/` | `ncdk/refchart/` | Reference chart utilities |
| `chart/format/notechart/` | `chartbase/notechart/` | Shared chart factory, builder, `IChartDecoder`, `IChartEncoder`, `Note` |
| `chart/format/sph/` | `chartbase/sph/` | SPH format decoder/encoder |
| `chart/format/osu/` | `chartbase/osu/` | OSU format decoder/encoder |
| `chart/format/bms/` | `chartbase/bms/` | BMS format decoder |
| `chart/format/o2jam/` | `chartbase/o2jam/` | O2Jam format decoder |
| `chart/format/quaver/` | `chartbase/quaver/` | Quaver format decoder |
| `chart/format/stepmania/` | `chartbase/stepmania/` | StepMania format decoder |
| `chart/format/ksm/` | `chartbase/ksm/` | K-Shoot Mania format decoder |
| `chart/format/midi/` | `chartbase/midi/` | MIDI format decoder |
| `chart/scoring/` | `libchart/libchart/` (scoring) | Scoring and difficulty calculation: `normalscore3`, `osu_pp`, `osu_starrate`, `erfunc`, `minacalc`, `enps` |
| `chart/difficulty/` | `sphere.models.DifficultyModel` | Chart difficulty orchestration and chartdiff field calculation |
| `chart/transform/` | `libchart/libchart/` (transform) | Chart manipulation: `NanoChart`, `Upscaler`, `Reductor`, `BlockFinder`, `GifResult`, `simplify_notechart`, `AnalogScratch`, `ScratchMapper` |

## Architecture Decisions

- **Single namespace**: `chart/` replaces three independent package roots (`ncdk`, `chartbase`, `libchart`).
- **Class naming**: Class annotations drop the old directory prefix. `ncdk2.Chart` → `chart.Chart`, `libchart.NanoChart` → `chart.NanoChart`.
- **Format separation**: Format-specific decoders live under `chart/format/<format>/`, with shared interfaces in `chart/format/notechart/`.
- **Scoring vs transform**: `libchart`'s dual responsibilities are split — scoring algorithms go to `chart/scoring/`, chart manipulation utilities go to `chart/transform/`.
- **NanoChart binary compatibility**: `NanoChart` uses the current `byte` buffer API while preserving the existing version 1 and version 2 wire format. Changes to its packing must be covered by exact-byte fixtures and decode round trips because replay events and exported `.nanochart` files depend on this format.

## Experimental Aim Data

Native osu! Mode=0 decoding stores objects in ordinary chart notes, with geometry and sounds in `Note.data` and CS/AR/OD in `Chart.data`. `RefChart` and `Restorer` deeply copy both data fields. Separate visual points preserve simultaneous objects and their ordering. This is an additive in-memory/thread-snapshot contract, not a change to SPH or other persistent chart formats. The gameplay implementation accepts circles, sliders, and spinners; spinner end times and slider source geometry/timing inputs are preserved, with separate path/timing helpers described in [format/osu/spec.md](format/osu/spec.md). See [../rizu/gameplay/aim/spec.md](../rizu/gameplay/aim/spec.md).

## Experimental Catch Data

Native Mode=2 charts store deterministic fruits, droplets, tiny droplets and bananas as ordinary notes with object-specific data, preserved by the common refchart path. See [../rizu/gameplay/catch/spec.md](../rizu/gameplay/catch/spec.md) for prototype generation, input and replay contracts.

## Migration Plan

1. Create `chart/` directory and spec (this file).
2. Move `ncdk/ncdk/` → `chart/core/`.
3. Move `ncdk/ncdk2/` → `chart/model/`.
4. Move `ncdk/chartedit/` → `chart/chartedit/`.
5. Move `ncdk/refchart/` → `chart/refchart/`.
6. Move `chartbase/` → `chart/format/`.
7. Split `libchart/libchart/` into `chart/scoring/` and `chart/transform/`.
8. Update all `require()` paths across the codebase.
9. Update class annotations to drop old prefixes.
10. Update `pkg_config.lua` to replace three roots with one.

## Future Work and Open Questions

- **Point and VisualPoint relationship**: Define and enforce the intended relationship between layer `Point` objects and `VisualPoint` objects. Timing-only points are currently valid and are created by converters, but ordinary points can also affect visual interpolation and scrolling without having a corresponding visual point. Decide whether every relevant point must be represented in each affected visual, or whether visuals and serializers must explicitly account for unreferenced points, then add model-level validation and regression tests for the chosen contract.
- **Chart model invariants**: Document the invariants of the chart module in nearby specs. Many assumptions about point ownership, timing propagation, visual interpolation, layer conversion, note references, ordering, and object lifetimes currently exist only implicitly in implementation code and tests.
- **Tempo range metadata**: `Chartmeta.tempo_min` and `Chartmeta.tempo_max` are currently populated only by the osu! and Quaver decoders. Add shared tempo-range extraction for other chart formats that can represent tempo changes, so library views can show a consistent BPM range instead of only a single `tempo` value.

## Native Mode Metadata

`sea.Chartmeta.mode` identifies decoded native mechanics: `mania` (column charts), `osu` (Aim), `taiko`, `catch`, or `sdvx`. File `format` and `inputmode` are independent. Existing Gamemode IDs 0/1/2 remain unchanged; Catch and SDVX append IDs 3/4. Decoders emit the field, including worker metadata snapshots. The explicit legacy KSH column decoder emits mania because it produces converted column data.

Gameplay reads `chartmeta.mode` directly. Preparation calls `ModeNotes.validate` to reject missing modes or mismatched native note types rather than guessing. Attempt/difficulty mode remains separate; this change does not introduce cross-mode conversion or change replay formats.

## Native Objects In The Common Note Model

- `Chart.data` holds chart-wide parameters, never the playable object collections. `Note.data` holds each object's geometry, interval/checkpoint data and sounds. This is an in-memory/worker contract; SPH persistence and binary replay formats are unchanged.
- osu Aim/Catch/Taiko decoders write notes directly and their rules/autoplay accept `Chart`. `Objects.get` selects note payload references for runtime iteration without reconstructing a chart DTO. Aim stacking clones the common chart through RefChart/Restorer before changing geometry. `ModeNotes` remains for SDVX and synthetic test fixtures.
- Native note types are mode-qualified (`osu:circle`, `taiko:roll`, `sdvx:button`, `sdvx:laser`, etc.), with weight zero. A compound object's complete interval belongs to its data, not an implicit column hold pair.
- Every native object gets a fresh `Visual:newPoint`; coincident objects retain insertion order via `compare_index`, including after refchart restoration. No change to note identity or collection collision rules is needed.
- Automatic chart audio excludes native playable notes when playable sounds are disabled, just as it excludes tap/hold sounds. Rules dispatch their hit feedback; ordinary sample notes still play automatically.
