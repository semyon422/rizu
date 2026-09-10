## Goal

Preserve native KSH button and laser geometry for the experimental SDVX implementation, without silently replacing lasers with directional holds.

## User Experience

`ChartDecoder:decode` now uses `SdvxDecoder` and the source-preserving `SdvxChart`. Ordinary KSH gameplay uses the experimental native SDVX rules. The legacy `decodeKsh` method remains available to explicit callers, but is no longer the normal file-decoding path. Invalid timing, symbols and incomplete laser chains produce explicit prototype diagnostics.

## Architecture Decisions

- Read normalized UTF-8 source independently from the legacy parser. Count only note rows when subdividing a measure; option/comment lines do not consume beats. Support CRLF, BOM and files without a final separator/newline.
- Time is in seconds relative to chart zero; `o` in milliseconds means audio starts at `-offset`. Preserve BPM changes and quarter-note beat coordinates, with per-measure `beat=n/d`. Mid-measure signature and mid-chart audio-offset changes are rejected.
- BT lanes 1–4: `1` chip, `2` hold; FX lanes 5–6: `2` chip, nonzero supported alphanumeric effect codes hold. Changing an FX effect inside a held run does not split its gameplay interval. A chip closes the preceding hold. Open holds close at the end of the final measure.
- Both lasers retain every explicit position anchor (51 symbols, normalized 0–1), linear/straight segments, reversals and chain breaks. `:` requires an active chain; a chain requires at least two explicit anchors. Chain duration ends at the final explicit anchor, not the following `-` row.
- Inspired by USC's `BeatmapFromKSH.cpp`, a changed position separated by <=1/8 quarter-note beat becomes a slam at the earlier source anchor. Its following segment starts at the slam time rather than inheriting the one-row delay. Consecutive slams preserve an intervening straight span. These are independently implemented prototype rules, not a claim of complete KSH-version parity.
- `laserrange_l/r=2x` marks the next chain as extended and resets at termination. Stored knob positions remain normalized; rendering can expand them to [-0.5, 1.5]. Unsupported in-chain range changes are rejected.
- DSP/effect definitions, sample changes, camera spins/tilt and scroll-only stops are not applied by this reader. They do not alter note timing. The first `m` audio path is retained; alternate pre-effected music is not selected. Scroll effects will need their own visual contract before gameplay claims compatibility with gimmick charts.
- `SdvxDecoder` stores one ordinary note per BT/FX object or laser chain, including complete segments in `Note.data`. Shared parameters use `Chart.data`; both are deeply copied through RefChart/Restorer. Tempo points support shared audio/chart infrastructure; no directional laser holds or duplicate button projections are generated. The existing `4bt2fx2laserleft2laserright` metadata identifier is retained for cache compatibility. Old column replays are explicitly rejected by native gameplay, not reinterpreted. Music uses first `m` path, `-o` audio start, `mvol/100` gain (0–10), and `po` preview start; `plength` is not a start offset.
- Bounds: 16 MiB source, 100000 note rows, 100000 button/laser-segment objects, BPM in (0, 1000000], signature components 1–192. Real charts use 16960 BPM and 1/192 measures for gimmicks; their timing is preserved rather than clamped. No competitive persistence or remote contract changes.
- Stray non-option header lines are retained in `warnings` with source line numbers. They do not contain note timing and may be skipped; malformed body rows remain errors. Gameplay integration must surface these warnings.

## Invariants

- Geometry and time are independent of UI frame rate.
- Source anchors are not collapsed based on direction.
- Legacy explicit conversion remains available, but ordinary gameplay must never run new mechanics against lossy legacy laser notes.

## Verification

Nearby tests cover BPM/meter/offset, option-row counting, BT/FX chips and holds, straight/reversing dual lasers, extended range, consecutive slams, EOF, malformed inputs, extreme real-chart timing and malformed-header warnings.

The reader successfully decoded all 90 `.ksh` files under `/home/semyon422/rhythm/charts` (B.B.K. mini vol.3, sdvx, ksm). One Vanaheimr file has a stray `.jpg` header line, retained as a warning. This proves acceptance, not exact USC object/timing parity. The selected cached **405nm(Shu※mix) [challenge]**, hash `60d0a68390bc26d361a4d6eb0db809ea`, index 1, is available through `mounted_charts/2/ksm/4/ADV.ksh`; live filesystem decoding yielded 392 button objects, 13 laser chains, 38 segments and 5 slams, with `music.ogg` available. Worker/refchart tests preserve source geometry, audio offset, preview start and gain above 100%. Runtime integration is tracked in [../../../rizu/gameplay/sdvx/spec.md](../../../rizu/gameplay/sdvx/spec.md).
