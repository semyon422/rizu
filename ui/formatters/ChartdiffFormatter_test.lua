local ChartdiffFormatter = require("ui.formatters.ChartdiffFormatter")

local test = {}

---@param t testing.T
function test.formats_played_chart(t)
	local formatter = ChartdiffFormatter({notes_count = 100, judges_count = 125, duration = 150, rate = 1.5}, {})
	t:eq(formatter:getLongNoteRatio().value, "25%")
	t:eq(formatter:getDuration(), "1:40")

	formatter:setChartdiff()
	t:eq(formatter:getLongNoteRatio().value, "0%")
	t:eq(formatter:getDuration(), "0:00")
end

return test
