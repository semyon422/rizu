local EditorAnalysisState = require("rizu.editor.EditorAnalysisState")

local test = {}

---@param t testing.T
function test.get_patterns_analyzed_returns_latest_analysis(t)
	local chart = {}
	local analysisState = EditorAnalysisState({
		analyze = function(analyzedChart)
			t:eq(analyzedChart, chart)
			return {
				value = "patterns",
			}
		end,
		format = function(patterns)
			t:eq(patterns.value, "patterns")
			return "formatted patterns"
		end,
	})

	t:eq(analysisState:getPatternsAnalyzed(), nil)

	analysisState:analyze(chart)

	t:eq(analysisState:getPatternsAnalyzed(), "formatted patterns")
end

return test
