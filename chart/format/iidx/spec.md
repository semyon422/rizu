## Goal

Provide read-only beatmania IIDX chart support for game `data` folders by parsing global metadata and `.ifs` sound archives into normal soundsphere chart objects.

## User Experience

- Players can add an IIDX `contents/data` folder as a normal library location.
- Library scanning discovers songs from `info/*/music_data.bin` and chart data from either `sound/*.ifs` archives or extracted `sound/<song_id>/` folders.
- Imported IIDX entries are playable notecharts for available SP/DP variations.

## Architecture Decisions

- IIDX locations are auto-detected by the library scanner instead of stored as a manual location type.
- The v1 library scanner treats `.ifs` archives as chartfile sets and hashes the internal `<song_id>/<song_id>.1` chart payload, so scores are tied to stable chart data rather than archive wrapper bytes.
- Metadata-listed extracted folders named `<song_id>` or `<song_id>-p0` are also chartfile sets. Their chart payload is the flat `<song_id>.1` file found directly in that folder; an `.ifs` archive takes priority when both forms exist.
- The decoder reads `.1` chart data and imports type-0/type-1 playable note timing/lanes plus type-7 autoplay sample events.
- Type-5 meter events set chart signatures as `value/raw_lane`, converted into quarter-note measure length for the shared timing model. For example, `value=3, raw_lane=4` is `3/4` and has a signature length of `3`.
- Type-2/type-3 events are treated as P1/P2 note keysound assignments. They are queued by side/lane and attached to the next playable note on that side/lane instead of becoming separate playable notes.
- `.s3p` and `.2dx` packs inside the song `.ifs` are exposed as chart sound resources. Chart sample id `0` is empty; positive ids map to one-based pack entries.
- S3P samples that wrap ASF/WMA payloads stay encoded in the chart resource layer and are decoded later by the BASS_FFMPEG-backed audio pipeline.
- `.2dx` gameplay keysound banks are selected from `music_data.bin` variation ident bytes when metadata is available. Ident byte `"0"` maps to `<song_id>.2dx`; other ident bytes map to `<song_id><ident>.2dx`, for example `"a"` maps to `<song_id>a.2dx`.
- When decoding without metadata, `.2dx` gameplay resources are omitted. Standalone `.1` decoding remains usable for chart structure, but keysound playback requires `music_data.bin` context.
- `<song_id>_pre.2dx` is preview audio and is not used as a gameplay keysound bank.
- Metadata `bga_filename` entries are imported as BMS-style BGA sprite notes on a dedicated `bga` visual at chart load. IIDX filenames are usually extensionless movie stems, so the decoder stores them as `.mp4` image resources; the resource finder may still resolve another video extension such as `.wmv` by stem.
- Metadata `bga_delay` is interpreted as a 60 fps frame offset. Negative values place the BGA note before chart time zero so video playback starts already advanced at song start.
- IIDX gameplay/editor/preview resource loading includes the content-level `movie` directory in addition to the song `sound/*.ifs` archive when a chart comes from an IIDX location.
- Metadata from the newest/highest-version `music_data.bin` is preferred, with older metadata folders filling missing song IDs.
