## Goal

The `chart/difficulty/` module owns chart difficulty and preview metadata calculation for library, gameplay, and server compute workflows.

## User Experience

- Chart difficulty values should be calculated consistently across client and server code.
- Difficulty-related binary blobs and rate tables should remain stable for persisted chartdiff records.

## Architecture Decisions

- Difficulty calculation lives under `chart/` because it operates on chart data and scoring algorithms rather than client UI or runtime state.
- `DifficultyModel` coordinates a registry of focused diffcalcs. Each diffcalc writes one or more fields onto `sea.Chartdiff`.
- `MsdDiffData` and `MsdDiffRates` preserve their binary encoding contracts for database storage.

## Invariants

- `DifficultyModel:compute` expects the chart main layer to be an `AbsoluteLayer` before and after calculation.
- Diffcalcs should use `DiffcalcContext:getSimplifiedNotes()` when they need normalized tap/hold/laser note data.
