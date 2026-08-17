# Mapperatorinator Integration

## Prototype workflow

The global command palette exposes **Mapperatorinator: Generate Chart**. On Linux it opens a native `zenity` audio picker and then shows a retained-mode settings modal. The prototype exposes editable Mapperatorinator repository/Python paths plus game mode, target difficulty, mania key count, and style year.

The audio picker is a blocking native process in this prototype. Online RPC return messages are therefore deferred by `rizu.online.SeaClient` until its normal game-update phase, avoiding coroutine re-entry when network replies arrive after a long modal interaction.

Generation runs outside the render thread through a LÖVE worker. The selected audio and generated `.osu` file are stored together in a unique directory under `userdata/charts/mapperatorinator/`. After inference completes, the integration asks the internal library location to cache that directory, selects the cached chart by content hash, and opens it in the editor.

Mapperatorinator output must still be reviewed manually.

## Prototype limits and future work

- The file picker is Linux/`zenity` only. Add native Windows and macOS pickers.
- Cancellation and structured inference progress are not implemented yet.
- A production integration should mirror Mapperatorinator's full web UI, including metadata, descriptors and negative descriptors, mapper/style IDs, hitsounds, timing/context/output controls, sampling controls, model/LoRA selection, precision/device controls, and diffusion settings.
- Replace subprocess output discovery with a stable machine-readable Mapperatorinator API.
