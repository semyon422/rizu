local SegmentedControl = require("ui.views.form.SegmentedControl")
local Slider = require("ui.views.form.Slider")

local labels = {
	osuod = "song_select.overall_difficulty",
	etternaj = "song_select.etterna_judge",
	bmsrank = "song_select.bms_rank",
}

---The picker for the value of a timing system: a slider for a range, segments for a list.
---@param system rizu.engine.scoring.TimingSystem
---@param value number
---@param width number
---@param localization ui.localization.Localization
---@param on_change fun(value: number)
---@return ui.views.form.FormControl? control nil for systems without a value.
return function(system, value, width, localization, on_change)
	---@param v number
	local function format(v)
		return system:formatValue(v)
	end
	local label = localization:get(labels[system.name] or "song_select.score_system")
	if system.range then
		return Slider({
			label = label,
			value = value,
			min = system.range.min,
			max = system.range.max,
			step = system.range.step,
			width = width,
			value_format = format,
			on_change = on_change,
		})
	elseif system.values then
		return SegmentedControl({
			label = label,
			options = system.values,
			value = value,
			format = format,
			on_change = on_change,
		})
	end
end
