local LunaticRaveScore = require("rizu.engine.ScoreEngine.scores.LunaticRaveScore")
local ScoreSystemFormatter = require("ui.formatters.ScoreSystemFormatter")

local test = {}

---@param t testing.T
function test.lr2_grades_use_exact_ninth_thresholds(t)
	local formatter = ScoreSystemFormatter(LunaticRaveScore(2))

	t:eq(formatter:getGrade(8 / 9), "AAA")
	t:eq(formatter:getGrade(7 / 9), "AA")
	t:eq(formatter:getGrade(6 / 9), "A")
	t:eq(formatter:getGrade(5 / 9), "B")
	t:eq(formatter:getGrade(4 / 9), "C")
	t:eq(formatter:getGrade(3 / 9), "D")
	t:eq(formatter:getGrade(2 / 9), "E")
	t:eq(formatter:getGrade(2 / 9 - 1e-6), "F")
end

return test
