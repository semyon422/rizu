## Goal

`chart/model/convert` converts chart layers between measure, interval, and absolute timing representations while preserving playable note order and timing well enough for the target workflow.

## User Experience

Players and library scanners should get stable chart timing for decoded charts. Editors and export paths should avoid surprising note movement when a chart is converted between timing models, especially on dense timing maps or charts with unusual tempo/signature data.

## Architecture Decisions

`MeasureInterval` preserves measure-derived timing directly. This is the preferred path for formats such as BMS that naturally decode into a `MeasureLayer`; direct `MeasureLayer:toInterval()` should not move notes.

`AbsoluteInterval` is intentionally approximate. It reconstructs interval timing from absolute seconds by snapping relative beat positions to a limited denominator set and by merging points close to `default_merge_time`. It also clamps very small beat durations with `min_beat_duration` to avoid unusable tempo maps. These choices were intended to keep converted interval charts editable and bounded, not to be a lossless inverse of `IntervalAbsolute`.

Known inaccuracy: dense or extreme absolute timing can produce large note-time deltas after `AbsoluteLayer:toInterval()`. The `bms_huge_tempo` fixture is a useful stress case: decoding is valid and direct `MeasureLayer:toInterval()` preserves notes, but forcing `MeasureLayer -> AbsoluteLayer -> IntervalLayer` can merge/quantize many dense timing points and move notes by over a second.

Future improvements should make this tradeoff explicit. Possible directions include preserving exact absolute offsets for dense regions, selecting finer denominators locally, lowering merge tolerance only where needed, or making lossy conversion opt-in for editor-friendly cleanup. Any change here should include regression tests that compare note times before and after conversion for dense timing fixtures.
