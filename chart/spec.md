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

- **Tempo range metadata**: `Chartmeta.tempo_min` and `Chartmeta.tempo_max` are currently populated only by the osu! and Quaver decoders. Add shared tempo-range extraction for other chart formats that can represent tempo changes, so library views can show a consistent BPM range instead of only a single `tempo` value.
