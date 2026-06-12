local class = require("class")

---@class rizu.editor.EditorLoadService
---@operator call: rizu.editor.EditorLoadService
local EditorLoadService = class()

---@param editorModel rizu.editor.EditorModel
function EditorLoadService:load(editorModel)
	editorModel:setLoaded(true)

	local editor = editorModel:getSettings()

	editorModel:loadChartData()
	editorModel:loadSession()
	editorModel:loadTimer(editor)
	editorModel:loadAudio()
	editorModel:loadMetronome()
	editorModel:loadInitialScroll()
	editorModel:loadBmsToolsContext()
	editorModel:loadMetadata()
end

return EditorLoadService
