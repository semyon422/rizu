## Goal

`chart/format/bms` imports BMS-family text charts into the shared notechart model while preserving legacy chart compatibility. The module supports `.bms`, `.bme`, `.bml`, and `.pms` through the existing decoder interfaces:

- `ChartDecoder:decode(s, hash)` for BMS/BME/BML charts.
- `PmsChartDecoder:decode(s, hash)` for PMS charts.
- `ChartFactory` registration remains the public integration point.

## User Experience

Players should be able to scan and play old BMS packs, malformed local charts, and PMS charts without parser crashes. When a chart contains unsupported or malformed data, the decoder should prefer ignoring that specific value over rejecting the whole chart, unless the surrounding chart model cannot be made valid.

## Architecture Decisions

The importer in `BMS.lua` is responsible for line classification, header/resource maps, channel data, keymode detection, and sorted time data. `ChartDecoder.lua` converts that parsed state into chart metadata, timing points, notes, BGA resources, and measure lines.

The parser intentionally keeps several legacy behaviors:

- Unknown data channels are ignored.
- Odd-length channel data is truncated to complete two-character pairs.
- `timePointLimit` remains `25000`.
- Invalid numeric resource values such as `#BPMAA nope` and `#STOPAA nope` are stored as absent values.
- Invalid inline tempo data and invalid extended tempo references are ignored during decode.
- If measure zero contains only unusable tempo markers, the base BPM is still inserted.
- `LNOBJ` and long-note channels keep the legacy pairing behavior, including replacing conflicting lane data at the same time point.
- PMS mode is selected by `PmsChartDecoder` setting `bms.pms` before import.

Base tempo behavior is compatibility-sensitive. A valid `#BPM` header becomes chart metadata tempo and the initial tempo when no valid measure-zero tempo is present. If no tempo is found at all, `BMS` falls back to its `primaryTempo`.

## Regression Strategy

Normal tests use committed synthetic fixtures in `TestFixtures.lua` and should cover headers, resources, BPM/STOP/signature timing, notes, BGA, mines, invisible notes, long notes, `LNOBJ`, mode detection, and malformed numeric data.

Real fixture sweeps are manual because the fixture roots are machine-local and large. For behavior-preserving refactors, compare old-vs-new import and decode output over these roots when available:

- `/workspaces/home/rhythm/charts/quarantined`
- `/workspaces/home/rhythm/charts/gamecrash`
- `/workspaces/home/rhythm/charts`
- `/workspaces/home/code/soundsphere/userdata/charts/local_test`
- `/workspaces/home/rhythm/charts/leafbms`

Problem folders such as `bms_invalid_num`, `bms_huge_tempo`, `bms_ln_bug`, and `crash_before_result` should be used for targeted checks before intentional behavior changes. Document any intentional output difference in this file or in the nearby tests.

## Testing

Run the focused BMS suite after parser or decoder edits:

```bash
./test chart/format/bms
```

Run the notechart factory tests when decoder registration, chart metadata, or shared notechart behavior is touched:

```bash
./test chart/format/notechart
```
