# Video Export (`rizu.video_export`)

## Goal
Turn frames drawn by a user interface into an MP4 with the system's `ffmpeg`. The game draws
nothing: a custom UI can put its own fonts, sprites and layout into the animation.

## Decisions
- **System ffmpeg, not bundled.** `FfmpegLocator` runs `ffmpeg -version` (output to `NUL` or `/dev/null`), so a binary
  that exists but cannot start counts as missing. The result is cached until `setPath`/`refresh`.
- **The UI renders.** `VideoExportJob` owns a canvas, calls `options.draw(time, dt, width, height)` with the canvas as
  render target, reads the pixels back with `love.graphics.readbackTexture` and writes raw RGBA to ffmpeg's stdin.
  Graphics state is pushed and popped around each call; an error in `draw` fails the job and deletes the output.
- **Pipe mode depends on the OS.** Windows needs `"wb"`: text mode turns every 0x0A byte of pixel data into
  0x0D 0x0A, which shifts rows and makes the picture roll like an old film. glibc `popen` rejects `"wb"` with
  `EINVAL`, so other systems use `"w"`.
- **Stepped, not blocking.** `step(budget)` renders frames until the budget (default 8 ms) is spent, at least one per
  call, so the UI keeps drawing and can show progress and cancel. The input closing makes ffmpeg encode the animation
  (`libx264`); that happens in one blocking `close()` in the `finishing` state, one step after the last frame, so
  the UI can show "Encoding" first.
- **stderr goes to `<output>.log`** because a write-mode pipe cannot read it back. It is deleted on success. Success
  means the output file exists and is not empty; the exit status is not reliable across Lua builds.
- **Time is explicit.** Frame `i` is drawn at `start_time + i / fps`. It never reads the wall clock.

## Format
The UI exports animated WebP (`libwebp_anim -lossless 0 -q:v 15 -compression_level 4`, small on a black
background at 30 fps). MP4 stays available through `options.format = "mp4"`: `FfmpegEncoder.codecArgs.mp4` is `libx264 -crf 23 -preset veryfast -pix_fmt yuv420p -movflags +faststart -an`.
H.264 in yuv420p plays inline in Discord and on every platform. It needs even dimensions. x264 encodes while the
frames arrive, so the `finishing` state is short. An MP4 was tried first (libwebp_anim has no motion
compensation, so size was proportional to the frame rate and the background; it needed a black panel under the
notes and 15 fps to stay small) and it was replaced by plain black.

The default UI draws the notes on plain black at 30 fps, with the title, artist and chart name bottom left.

## No audio
The preview sound of many charts is not a file: keysounded charts (BMS, IIDX, o2jam) mix samples in the engine's
memory (`AudioPreviewGenerator`). Adding it would mean an offline render (`Engine:renderWave`) of the clip range,
and for single-file charts a second ffmpeg input with the playback rate and offset applied. Not done; a later
version can feed a rendered WAV as a second input.

## Surface
`rizu.api.VideoExport` (`api.video_export`) wraps this for UIs: `isAvailable`, `start`, `update`, `isRunning`,
`getState`, `getProgress`, `getError`, `getOutputPath`, `cancel`, `makePath`. Output lands in `userdata/export` as `.mp4`.
`rizu.api.Media:createNotesPreview(chartview)` gives a notes preview with its own clock and its own note skin (loaded in the background, so it works with the song select preview off): `isReady`, `draw(time, dt, w, h)`, `release`.

The default UI's `ui.modals.video_export.VideoExport` is the example. While exporting it sets `locked`, and
`ui.ModalManager` ignores close and replace requests for a locked modal (Escape, click outside, another modal).

## Limits
- WebP and MP4, no audio. `FfmpegEncoder.codecArgs` is the place to add formats.
- A `draw` that lays out components must do so at the export size, not the window size.
- If ffmpeg dies early, writing to the pipe fails and the job reports it; a platform that raises `SIGPIPE` for a
  closed pipe would end the process instead.
