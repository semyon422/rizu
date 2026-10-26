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

## Judging and leaderboard accuracy

`replay_base.auto_timings` is on by default: each mania chart is judged with its auto timings (`TimingSystems.getAuto`): the chart's own timings, or its format's system with that system's default value (StepMania: Etterna J4), and osu!mania with score V1.

Off, mania plays are judged with `timings.system` (`"osuod"` by default), with the value of that system (`timings.osuod`, `timings.etternaj`, `timings.bmsrank`) and, for osu!mania, `timings.osu_score_version`.

The leaderboard of a mania chart shows local scores in the system plays of it are judged with, the auto timings or the picked one, scored again from their hits, with that system's grades; local scores without hits show none. `chartplays.accuracy` holds normalscore, which online scores, other gamemodes and every score while `select.rescore` is off show. Turning it off skips rescoring for slow computers. The list stays ordered by rating.

Every saved score stores its hits (`chartplay_hits`): what the score engine received, enough to score it in any system without the replay. Older scores get them in the background at startup, played again from their replays. `scores.hits_version` is internal: the `ChartplayHitsRepo.hits_version` of the last update that went through every score. Such an update runs only when it differs, so a score whose chart or replay is gone is not retried at every start.

`scores.compute_version` is internal too: the `ScoreTask.version` of the last recompute that went through every score. When it differs, every local score is computed again in the background at startup (rating, accuracy and hits), before the hits update, which then finds only the scores the recompute could not play again. `scores.recompute_since` holds when the unfinished recompute began, 0 for none: a run takes only the scores computed before it, so a stopped one goes on at the next start.

## Persistence

`Config` receives a filesystem and path at construction. `load()` and `save()` use flat JSON. Only values differing from defaults are stored. Unknown persisted keys are ignored for compatibility; invalid values make loading fail without changing the current config.
