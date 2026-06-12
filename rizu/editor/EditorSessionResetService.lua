local class = require("class")
local Changes = require("Changes")

---@class rizu.editor.EditorSessionResetContext

---@class rizu.editor.EditorSessionResetService
---@operator call: rizu.editor.EditorSessionResetService
local EditorSessionResetService = class()

---@param context rizu.editor.EditorSessionResetContext
function EditorSessionResetService:reset(context)
	context:analyzePatterns()
	context:setChanges(context:newChanges())
	context:loadGraphs()
	context:setResourcesLoaded(false)
	context:setSessionTime(0)
	context:finishSelection()
end

---@return Changes
function EditorSessionResetService.newChanges()
	return Changes()
end

return EditorSessionResetService
