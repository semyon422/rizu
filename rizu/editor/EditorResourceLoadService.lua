local class = require("class")

---@class rizu.editor.EditorResourceLoadService
---@operator call: rizu.editor.EditorResourceLoadService
local EditorResourceLoadService = class()

---@param editorModel rizu.editor.EditorModel
---@param resources {[string]: string}
function EditorResourceLoadService:load(editorModel, resources)
	editorModel:loadAudioResources(resources)
	editorModel:renderWave()
	editorModel:genGraphs()

	editorModel:setResourcesLoaded(true)
end

return EditorResourceLoadService
