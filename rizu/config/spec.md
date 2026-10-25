## Goal

Provide one small, typed, observable configuration store for Rizu settings.

## Design

Configuration keys are plain strings. `rizu.config.Settings` contains optional constants for shared keys and constructs the application settings store. `Config` owns defaults, explicit values, subscriptions, and JSON persistence.

Defaults are registered directly on a config:

```lua
config:setDefaultNumber("audio.volume.master", 0.5, 0, 1, 0.01)
config:setDefaultChoice("graphics.interface", "new", {"old", "new"})
config:setDefaultBoolean("misc.show_fps", false)
config:setDefaultString("profile.name", "")
config:setDefaultKeyBindings("ui.cancel", {{key = "escape"}})
```

Number definitions include minimum, maximum, and step metadata. Number setters reject values outside the configured range. Key bindings are arrays of `{key, control?, shift?, alt?, super?, allow_repeat?}` records. Typed getters and setters fail for unknown keys, incorrect types, invalid bindings, and invalid choices. Duplicate defaults also fail. There are no setting objects, nested schema discovery, transient state, commits, or a config registry.

## Changes

Callers can subscribe to one key or every key:

```lua
local unsubscribe = config:subscribeBoolean("misc.show_fps", function(value, old_value, key)
	view:setVisible(value)
end)

unsubscribe()
```

Callbacks run only when the effective value changes.

## Timing offsets

Universal and per-format audio offsets use the existing `gameplay.offset.audio_mode.*` and `gameplay.offset.format.*` JSON keys. Format-key suffixes remain `osu`, `qua`, `sm`, and `ksh`, mapped to decoded formats `osu`, `quaver`, `stepmania`, and `ksm`. The universal control sets both playback modes; existing mode-specific values are preserved. These settings add to Chart-local `local_offset` metadata and adjust only the audio source. Compensated audio position leaves judgement, visual, and replay clocks unchanged. `gameplay.offset.input` shifts manual mania input on the judgement clock; the shifted times are what replays record, so replays and autoplay never apply it. Visual timing offsets remain unsupported; legacy `settings.lua` is not loaded.

## Stored accuracies

`scores.stored_accuracies` lists the score systems whose accuracy is stored with every local score, besides normalscore, which `chartplays.accuracy` always holds. It is a comma-separated string of tokens, `"auto"` by default. `auto` is the chart's auto timings, which every play is judged with for now (`TimingSystems.getAuto`): the chart's own timings, or its format's system with that system's default value (StepMania: Etterna J4), and osu!mania with score V1; the others are `name[:value[:osu score version]]` with a timings name, for example `osuod:9:1` (osu!mania V1, OD 9), `etternaj:4` or `quaver`. Invalid tokens and systems without accuracy are ignored. A change applies to scores saved afterwards; recalculating the accuracies applies it to the old ones.

`select.accuracy_system` is the token of `scores.stored_accuracies` whose accuracy the leaderboard shows, `"auto"` by default. A token that is no longer stored counts as `"auto"`.

## Persistence

`Config` receives a filesystem and path at construction. `load()` and `save()` use flat JSON. Only values differing from defaults are stored. Unknown persisted keys are ignored for compatibility; invalid values make loading fail without changing the current config.
