local class = require("class")

---@class rizu.editor.EditorResourceLoadContext

---@class rizu.editor.EditorResourceLoadService
---@operator call: rizu.editor.EditorResourceLoadService
local EditorResourceLoadService = class()

---@param context rizu.editor.EditorResourceLoadContext
---@param resources {[string]: string}
function EditorResourceLoadService:load(context, resources)
	context:loadAudioResources(resources)
	context:renderWave()
	context:genGraphs()

	context:setResourcesLoaded(true)
end

return EditorResourceLoadService
