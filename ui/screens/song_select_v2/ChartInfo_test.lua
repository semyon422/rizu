local utf8 = require("utf8")
local ChartInfo = require("ui.screens.song_select_v2.ChartInfo")

local test = {}

---@param t testing.T
function test.approach_flows_to_the_target_and_lands_on_it(t)
	local value = 10
	local last = value
	for _ = 1, 600 do
		value = ChartInfo.approach(value, 20, 1 / 60, 0.02)
		t:assert(value >= last and value <= 20)
		last = value
	end
	t:eq(value, 20)
	t:eq(ChartInfo.approach(20, 10, 1, 0.02), 10, "a long frame does not overshoot")
end

---@param t testing.T
function test.parse_cell_takes_counts_percents_and_durations(t)
	t:tdeq({ChartInfo.parseCell("417")}, {417, "%d"})
	t:tdeq({ChartInfo.parseCell("12%")}, {12, "%d%%"})
	t:tdeq({ChartInfo.parseCell("1:40")}, {100, "%d:%02d"})
	t:eq(ChartInfo.parseCell("4K"), nil)
	t:eq(ChartInfo.parseCell("120-180"), nil)
end

---@param t testing.T
function test.pad_cell_grays_the_leading_zeros(t)
	t:tdeq({ChartInfo.padCell("NOTES", 417, "%d")}, {"00417", 2})
	t:tdeq({ChartInfo.padCell("NOTES", 0, "%d")}, {"00000", 4})
	t:tdeq({ChartInfo.padCell("NOTES", 99999, "%d")}, {"99999", 0})
	t:tdeq({ChartInfo.padCell("LN", 7, "%d%%")}, {"007%", 2})
	t:tdeq({ChartInfo.padCell("LN", 100, "%d%%")}, {"100%", 0})
	t:tdeq({ChartInfo.padCell("LENGTH", 65, "%d:%02d")}, {"01:05", 1})
	t:tdeq({ChartInfo.padCell("LENGTH", 5, "%d:%02d")}, {"00:05", 4})
	t:tdeq({ChartInfo.padCell("LENGTH", 600, "%d:%02d")}, {"10:00", 0})
	t:tdeq({ChartInfo.padCell("BPM", 90, "%d")}, {"090", 1})
end

---@param t testing.T
function test.format_pattern_reads_labels_as_words(t)
	t:eq(ChartInfo.formatPattern("full_ln"), "Full Ln")
	t:eq(ChartInfo.formatPattern("dense_chordstream"), "Dense Chordstream")
	t:eq(ChartInfo.formatPattern("stream"), "Stream")
	t:eq(ChartInfo.formatPattern("4242chordjack"), "4242chordjack")
end

---@param t testing.T
function test.fit_text_cuts_with_an_ellipsis(t)
	local font = {getWidth = function(_, text) return utf8.len(text) * 10 end} --[[@as love.Font]]
	t:eq(ChartInfo.fitText(font, "chordjack", 100), "chordjack")
	t:eq(ChartInfo.fitText(font, "chordjack", 50), "chor…")
	t:eq(ChartInfo.fitText(font, "chordjack", 5), nil)
end

return test
