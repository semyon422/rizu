# Mapperatorinator Integration

## Workflow

The global command palette exposes **Mapperatorinator: Generate Chart**. It opens LÖVE's native asynchronous audio file dialog and then shows a sectioned retained-mode settings modal.

The modal mirrors Mapperatorinator's practical web-generation controls:

- editable repository, Python, LoRA, reference beatmap, and background paths;
- model, game mode, target difficulty, metadata, and map difficulty properties;
- year, mapper/beatmap IDs, mania style ratios, positive descriptors, and negative descriptors;
- seed, CFG scale, temperature, top-p, partial-map time range, device, precision, and attention implementation;
- hitsounds, super timing, diffusion positions, `.osz` export, reference context, add-to-map, and managed-reference overwrite options;
- JSON preset import, export, and reset.

Descriptor values are entered as comma-separated strings rather than the web UI's large three-state descriptor tree. Presets store Soundsphere's native setting keys, not Mapperatorinator Hydra YAML.

Audio, reference/background, and preset selection use `love.window.showFileDialog`, so dialogs are asynchronous and use the platform's native picker without an external `zenity` dependency.

Generation runs outside the render thread through a LÖVE worker. Audio, optional reference/background copies, and generated files are stored together in a unique directory under `userdata/charts/mapperatorinator/`. Reference overwrite only changes the managed copy; the user's source `.osu` is never overwritten. After inference completes, the integration asks the internal library location to cache that directory, selects the cached chart by content hash, and opens it in the editor.

Mapperatorinator output must still be reviewed manually.

## Remaining limits

- Generation subprocess execution and host-filesystem access remain Linux-only, although file dialogs are cross-platform.
- Cancellation and structured inference progress are not implemented yet.
- Descriptor entry does not yet mirror the web UI's searchable grouped tri-state selector.
- Less commonly used Hydra-only expert controls remain configuration-file territory, including detailed timing temperatures, lookback/lookahead, beam/search knobs, server batching/fast-loop controls, and low-level diffusion checkpoint/refinement controls.
- Replace subprocess output discovery with a stable machine-readable Mapperatorinator API.
