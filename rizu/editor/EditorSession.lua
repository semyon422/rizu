local class = require("class")
local Changes = require("Changes")
local Point = require("chart.chartedit.Point")
local pattern_analyzer = require("chart.scoring.pattern_analyzer")

---@class rizu.editor.EditorSession
---@operator call: rizu.editor.EditorSession
---@field point chartedit.Point
---@field noteSkin any
---@field selectRect number[]?
---@field selectStartTime number?
---@field state string
---@field patterns_analyzed string
---@field dragging boolean?
local EditorSession = class()

---@param editorModel rizu.editor.EditorModel
function EditorSession:new(editorModel)
	self.point = Point()
	self.state = "info"
end

---@param editorModel rizu.editor.EditorModel
function EditorSession:load(editorModel)
	self.patterns_analyzed = pattern_analyzer.format(pattern_analyzer.analyze(editorModel.chart))

	editorModel:setChanges(Changes())
	editorModel.graphsGenerator:load()

	editorModel:setResourcesLoaded(false)

	self.point = Point()
	editorModel:getDtpAbsolute(0):clone(self.point)
end

return EditorSession
