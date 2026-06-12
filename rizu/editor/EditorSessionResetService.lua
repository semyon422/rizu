local class = require("class")
local Changes = require("Changes")

---@class rizu.editor.EditorSessionResetService
---@operator call: rizu.editor.EditorSessionResetService
local EditorSessionResetService = class()

---@param editorModel rizu.editor.EditorModel
function EditorSessionResetService:reset(editorModel)
	editorModel:analyzePatterns()
	editorModel:setChanges(Changes())
	editorModel.graphsGenerator:load()
	editorModel:setResourcesLoaded(false)
	editorModel:setSessionTime(0)
	editorModel:getSelectionState():finish()
	editorModel:syncSessionAliases()
end

return EditorSessionResetService
