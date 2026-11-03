# Plugins

A plugin is a package: a folder or `.zip` in `userdata/pkg` with a `pkg.json`. Its `types` say what it adds:

- `ui`: a module returning a `rizu.app.UserInterface` class.
- `require`: a module the game requires at start, in the main thread and in every worker thread, before the library loads. Plugins register things from here, or patch the game.

## Difficulty calculators

A calculator rates unmodded mania charts at rate 1. The library rates every chart that misses its value after each scan and at start, and stores it in `chart_difficulties`. It then shows up in Settings → Difficulty type, sorts and filters (`d>25`) like the built-in ones.

`userdata/pkg/notes_per_second/pkg.json`:

```json
{
	"name": "notes_per_second",
	"version": 1,
	"types": {"require": "notes_per_second.init"}
}
```

`userdata/pkg/notes_per_second/notes_per_second/init.lua`:

```lua
local Calculators = require("rizu.library.Calculators")

Calculators.add({
	name = "nps", -- the setting is "calc:nps", shown as "nps"
	version = 1, -- raise it to rate every chart again
	---@param ctx chart.DiffcalcContext
	---@param chartmeta sea.Chartmeta
	compute = function(self, ctx, chartmeta)
		local notes = ctx.chartdiff.notes_count
		local duration = ctx.chartdiff.duration
		if not notes or not duration or duration <= 0 then
			return nil -- not rated: shown as "—" and matched by no filter
		end
		return notes / duration
	end,
})
```

- `compute` returns a number, or nil for charts it doesn't rate. Values are stored in hundredths.
- `ctx.chart` is the decoded chart, `ctx:getSimplifiedNotes()` its notes, and `ctx.chartdiff` the stored default chartdiff (an empty table if the chart has none).
- An error in `compute` is shown in the library errors, and the chart is stored as not rated, so it isn't decoded again at every start. Fix it and raise `version`.
- A calculator with more values, such as skillsets, names them in `keys = {"stream", "jack"}` and returns `{[0] = headline, stream = 25.1, jack = 23.4}`. Key 0 is the headline, which song select shows, sorts and filters by; key i is `keys[i]`. Only append names to `keys`: the stored rows use their positions.

## Play ratings

A calculator can rate plays too, with `computePlay(ctx, score_engine)`, beside `compute` or instead of it. The value goes to `chartplay_ratings`, one per play and calculator. The library worker rates a play after it is saved and, for older plays, at start, by playing their replays again, so a slow calculator doesn't stall the game.

- `ctx` is the played chart with the play's modifiers, and `ctx.rate` its rate. Its notes are not scaled by the rate.
- `score_engine` holds the play's events. Add the score system you need to judge them, such as `score_engine:addScoreSystem(EtternaAccuracy(4)):getAccuracy()` for Wife3 J4. It judges the events again with its own windows: what the play hit and missed stays as played.
- A calculator that only rates plays has no `compute`, and is not a difficulty type.

## Interface

`ui.Extensions.add(function(ui) ... end)` from the `require` module extends the default interface. It runs every time the interface loads, once its screens and commands exist:

- `ui.screen_manager:register(screen)` and `ui:setScreen(screen)` for a screen of the plugin's own.
- `ui.command_registry:pushContext("my_plugin", commands)` for commands in the command palette.
- Existing screens, such as `ui.song_select`, can be patched from here.

An error in the function is shown as a notification, and the rest of the interface loads.

