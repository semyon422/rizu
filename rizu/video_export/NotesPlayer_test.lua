local NotesPlayer = require("rizu.video_export.NotesPlayer")

local test = {}

---@param t testing.T
function test.maps_columns_by_the_replay_order(t)
	local player = assert(NotesPlayer.fromChartview({chartdiff_inputmode = "4key"}, {2, 1, 3, 4}, 1.5))
	t:eq(player.input_mode, "4key")
	t:eq(player.rate, 1.5)
	t:tdeq(player.column_map, {[2] = 1, [1] = 2, [3] = 3, [4] = 4})
end

---@param t testing.T
function test.keeps_the_column_order_without_a_matching_replay_order(t)
	local player = assert(NotesPlayer.fromChartview({chartdiff_inputmode = "4key"}, {1, 2}, 1))
	t:tdeq(player.column_map, {1, 2, 3, 4})
end

---@param t testing.T
function test.refuses_charts_without_a_mania_preview(t)
	t:eq((NotesPlayer.fromChartview({chartdiff_inputmode = "4key", chartmeta_mode = "taiko"}, nil, 1)), nil)
	t:eq((NotesPlayer.fromChartview({}, nil, 1)), nil)
end

return test
