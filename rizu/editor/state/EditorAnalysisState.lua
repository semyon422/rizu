local class = require("class")
local pattern_analyzer = require("chart.scoring.pattern_analyzer")

---@class rizu.editor.EditorPatternAnalyzer
---@field analyze fun(chart: chart.Chart): any
---@field format fun(patterns: any): string

---@class rizu.editor.EditorAnalysisState
---@operator call: rizu.editor.EditorAnalysisState
---@field analyzer rizu.editor.EditorPatternAnalyzer
---@field patternsAnalyzed string?
local EditorAnalysisState = class()

---@param analyzer rizu.editor.EditorPatternAnalyzer?
function EditorAnalysisState:new(analyzer)
	self.analyzer = analyzer or pattern_analyzer
end

---@param chart chart.Chart
function EditorAnalysisState:analyze(chart)
	local analyzer = self.analyzer
	self.patternsAnalyzed = analyzer.format(analyzer.analyze(chart))
end

---@return string?
function EditorAnalysisState:getPatternsAnalyzed()
	return self.patternsAnalyzed
end

return EditorAnalysisState
