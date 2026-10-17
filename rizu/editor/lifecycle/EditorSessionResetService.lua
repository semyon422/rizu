local class = require("class")
local Changes = require("Changes")

---@class rizu.editor.EditorSessionResetContext
---@field getAnalysisState fun(self: rizu.editor.EditorSessionResetContext): rizu.editor.EditorAnalysisState
---@field getChart fun(self: rizu.editor.EditorSessionResetContext): chart.Chart
---@field setChanges fun(self: rizu.editor.EditorSessionResetContext, changes: Changes)
---@field getGraphsGenerator fun(self: rizu.editor.EditorSessionResetContext): rizu.editor.GraphsGenerator
---@field setResourcesLoaded fun(self: rizu.editor.EditorSessionResetContext, loaded: boolean)
---@field setSessionTime fun(self: rizu.editor.EditorSessionResetContext, time: number)
---@field getSelectionState fun(self: rizu.editor.EditorSessionResetContext): rizu.editor.EditorSelectionState

---@class rizu.editor.EditorSessionResetService
---@operator call: rizu.editor.EditorSessionResetService
local EditorSessionResetService = class()

---@param context rizu.editor.EditorSessionResetContext
function EditorSessionResetService:reset(context)
	context:getAnalysisState():analyze(context:getChart())
	context:setChanges(self.newChanges())
	context:getGraphsGenerator():load()
	context:setResourcesLoaded(false)
	context:setSessionTime(0)
	context:getSelectionState():finish()
end

---@return Changes
function EditorSessionResetService.newChanges()
	return Changes()
end

return EditorSessionResetService
