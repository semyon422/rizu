local NotesPreviewPlayer = require("rizu.preview.NotesPreviewPlayer")
local Settings = require("rizu.config.Settings")
local SphPreview = require("chart.format.sph.SphPreview")

local test = {}

---@param t testing.T
function test.selection_settings_and_clear(t)
	local enabled, scale = true, false
	local settings = {
		getBoolean = function(_, key)
			if key == Settings.keys.select.chart_preview then return enabled end
			return scale
		end,
		getNumber = function() return 2 end,
	}
	local player = NotesPreviewPlayer(settings, {rate = 2, getTime = function() return 3 end}, {columns_order = {3, 1, 2}})
	local cv = {chartdiff_inputmode = "3key", notes_preview = SphPreview:encode({{offset = 0, notes = {true}}, {offset = 1}})}
	player:setChartview(cv)
	t:eq(player.notes.columns[1][1].time, 0)
	t:tdeq(player.column_map, {2, 3, 1})
	player:update()
	t:eq(player.time, 3)
	t:eq(player.rate, 1)
	scale = true
	player:update()
	t:eq(player.rate, 2)
	enabled = false
	player:setChartview(cv)
	t:eq(player.notes, nil)
	enabled = true
	cv.notes_preview = "bad"
	t:eq(player:setChartview(cv), false)
	t:eq(player.notes, nil)
	player:setChartview(nil)
	t:eq(player.notes, nil)
end

return test
