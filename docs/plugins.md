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
- A calculator with more outputs, such as skillsets, keeps its headline value here and the rest in its own storage.
