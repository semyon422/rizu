local class = require("class")

---@class rizu.editor.EditorResourceLoadContext
---@field getPlaybackService fun(self: rizu.editor.EditorResourceLoadContext): rizu.editor.EditorPlaybackService
---@field getPlaybackContext fun(self: rizu.editor.EditorResourceLoadContext): rizu.editor.EditorPlaybackContext
---@field getAnalysisService fun(self: rizu.editor.EditorResourceLoadContext): rizu.editor.EditorAnalysisService
---@field getAnalysisContext fun(self: rizu.editor.EditorResourceLoadContext): rizu.editor.EditorAnalysisContext
---@field setResourcesLoaded fun(self: rizu.editor.EditorResourceLoadContext, loaded: boolean)

---@class rizu.editor.EditorResourceLoadService
---@operator call: rizu.editor.EditorResourceLoadService
local EditorResourceLoadService = class()

---@param context rizu.editor.EditorResourceLoadContext
---@param resources {[string]: string}
function EditorResourceLoadService:load(context, resources)
	context:getPlaybackService():loadEditorAudioResources(context:getPlaybackContext(), resources)
	context:getAnalysisService():renderWave(context:getAnalysisContext())
	context:getAnalysisService():genGraphs(context:getAnalysisContext())

	context:setResourcesLoaded(true)
end

return EditorResourceLoadService
