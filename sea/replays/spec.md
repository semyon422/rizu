## Goal

Keep saved replays usable as the replay format, gameplay engine, and official modifiers evolve. Historical replay data is converted in memory at load time so the rest of the game can operate on the current replay shape.

## User Experience

- An old replay should load and play on a current game version without requiring the user to rewrite the replay file.
- Recomputed results may differ from the result produced by the original game version, but they should remain close enough to represent the same play.
- Compatibility work should prioritize replay availability and a credible result over exact historical engine emulation.

## Compatibility Invariants

- `sea.replays.ReplayLoader` is the compatibility boundary. Callers should use it instead of decoding replay files directly when they need a replay for playback or computation.
- Conversion is on-the-fly and non-persistent. The serialized bytes and their replay hash remain unchanged; only the decoded in-memory object is migrated.
- Supported historical replay formats should be converted to the current runtime shape before validation and use.
- Exact result reproduction is not guaranteed. Timing, scoring, engine, and modifier compatibility should keep the result close to the original play where practical.
- Chart parser behavior is not versioned for replay compatibility. Parser fixes or changes may alter the chart produced from the same file and are allowed to break or materially change replay recomputation.
- Replay compatibility does not require preserving every modifier forever. A modifier may be removed or reclassified as custom when the maintenance cost of its historical behavior is too high. The loader should still handle its saved configuration gracefully where practical, even if the original transformation is no longer reproduced.

"Close" is currently a qualitative goal. There is no repository-wide numeric tolerance for score, accuracy, judgments, or other computed fields.

## Serialized Replay Versions

| Version | Event payload | Current loading behavior |
|---|---|---|
| Pre-v1 (no `version`) | Legacy `events`, normally compressed and base64-encoded | Converts legacy fields, timings, modifier names/configuration, and events; produces a `Replay` with `version = 0` and modern frames. |
| v1 | Compressed and base64-encoded event tuples | Decodes events, converts them to modern frames, restores timing-related metatables, and retains `version = 1`. |
| v2 | Compressed and base64-encoded replay frames | Decodes modern frames, restores timing-related metatables, and retains `version = 2`. This is the format written by `rizu.ReplayFactory`. |

Any other nonzero replay version currently raises `invalid replay version`. Versions 1 and 2 are assumed to already contain the complete modern replay-base fields; unlike pre-v1 data, they do not receive field-by-field defaults or legacy modifier conversion.

## Loading And Conversion Pipeline

1. `ReplayCoder.decode` parses JSON and decodes either the v1 event blob or v2 frame blob.
2. `ReplayConverter.convert` converts the decoded object to the runtime `sea.Replay` shape.
3. `ReplayLoader.load` validates the converted object against `Replay.struct`.
4. Gameplay and server computation parse the current chart, apply the replay's modifiers and column order, then feed the converted frames into the current rhythm engine.

The chart is parsed at step 4 by the installed parser implementation. Replays store the chart hash and index, not a parser version or a parsed chart snapshot.

## Modifier Compatibility

Modifier configurations are serialized as `{id, version, value}`. `ModifierModel:add` copies the current modifier class version into new configurations, and all current built-in modifier classes inherit version `0`.

### Official modifiers

Official modifiers should preserve backward compatibility when their behavior changes:

- Keep a stable registry ID for as long as the modifier remains supported.
- Increment the modifier class version when a behavior change would affect historical replay computation.
- Branch or migrate using the version saved in the modifier configuration so old configurations retain their historical behavior as closely as practical.
- Add fixtures or focused tests for every supported historical behavior.

Versioning is a modifier-level contract, not a snapshot of the chart parser or the whole gameplay engine. It therefore cannot guarantee identical results by itself.

### Custom, removed, and reclassified modifiers

Custom modifiers do not carry the same historical-behavior guarantee as official modifiers. Official modifiers may be removed or reclassified as custom to cap the long-term compatibility burden. Compatibility code may migrate an obsolete modifier into replay-base fields, ignore it, or retain only enough information for the replay to load.

The current registry contains a `Custom` marker modifier, while `ReplayBase.custom` is separate replay metadata. There is not yet a general plugin-like API for defining, registering, and versioning user-authored modifier implementations.

### Current compatibility implementations

- Pre-v1 named modifiers are mapped to stable numeric IDs.
- Deleted time-rate and constant-speed modifiers are migrated into `rate` and `const` replay-base fields.
- Unknown pre-v1 named modifiers are dropped.
- Unknown numeric modifier IDs pass structural validation but are skipped by `ModifierModel` during application.
- Disabled legacy boolean modifiers are removed instead of being converted into invalid `value = false` configurations.
- Obsolete fields on legacy modifier records are removed after their value and version have been migrated.
- Pre-v1 `MultiplePlay` and `MultiOverPlay` values are adjusted for their historical encoding.
- Legacy Automap is marked with modifier version `-1`; Automap is currently the only modifier whose implementation selects historical behavior from the saved version.
- Old numeric values for modifiers whose modern values are strings are converted through the modifier's indexed value list.

Modifier versions are currently conventions rather than centrally enforced migrations. Changing an official modifier without bumping and handling its version can silently change old replay results.

## Verification Status

Current automated coverage verifies:

- loading synthetic pre-v1, v1, and v2 files through the complete `ReplayLoader` pipeline,
- all three historical timing-field generations found in the replay corpus,
- legacy event conversion and replay metadata defaults,
- deleted, disabled, renamed, indexed-value, obsolete-field, and unknown-ID modifier handling,
- the v1 event codec, v2 frame codec, event/frame primitives, osu! replay conversion, and round-tripping a complete current replay.

Tests use small synthetic inputs and do not depend on external user or production replay storage. They do not yet compare historical and modern computation results.

### Corpus audit

The July 2026 compatibility audit inspected the JSON envelope of 13,470 local files and 142,809 production-storage files. The valid envelopes contained only the three known formats: 119,714 pre-v1 files, 36,075 v1 files, and 90 v2 files.

After legacy boolean and obsolete modifier-field conversion fixes, 155,802 files pass metadata conversion and current `Replay` validation when their large encoded event payload is replaced with an empty decoded payload. The remaining files consist of:

- 399 zero-byte production files and one local `.keep` file,
- 26 pre-v1 files with a missing or invalid chart MD5 hash,
- 51 files over the current 10-modifier validation limit, including pathological files with hundreds of repeated modifiers.

Representative real files from every known root replay version and the major historical field generations were also fully decoded through `ReplayLoader`. This audit is evidence about the inspected snapshots, not a test dependency or a permanent exhaustive guarantee.

The local `userdata/replays` path is intended to hold real replay samples, but it is user data rather than a tracked test-fixture directory. A compatibility audit must not assume that every checkout contains the same files.

## Change Checklist

When changing replay serialization, loading, computation, or an official modifier:

1. Identify every historical replay or modifier version affected by the change.
2. Keep conversion at the `ReplayLoader` boundary and preserve the original replay bytes/hash.
3. For an official modifier behavior change, bump its version and retain the old branch or add an explicit migration.
4. Verify loading, conversion, and recomputation with representative historical replay fixtures.
5. Check whether observed drift is caused by the replay format, modifier behavior, the rhythm/scoring engine, or an intentionally unversioned chart parser.
6. Document any accepted loss of compatibility when deleting or reclassifying a modifier.

## Future Work and Open Questions

- Keep representative files for every known format version and modifier-version transition in the developer replay corpus for manual audits. Add small repository-owned synthetic cases whenever that corpus reveals a new conversion contract.
- Add end-to-end recomputation checks with recorded original results. Define per-metric tolerances only where they provide a useful regression signal; exact equality is not the compatibility goal.
- Make custom modifier creation and registration simpler, including an explicit distinction between compatibility-maintained official modifiers and best-effort custom modifiers.
