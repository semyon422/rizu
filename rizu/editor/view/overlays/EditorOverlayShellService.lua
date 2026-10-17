local class = require("class")

---@class rizu.editor.EditorOverlayShellState
---@field activeTab string
---@field tabs string[]
---@field resourcesLoaded boolean

---@class rizu.editor.EditorOverlayShellInput
---@field activeTab string

---@class rizu.editor.EditorOverlayShellContext
---@field getViewState fun(self: rizu.editor.EditorOverlayShellContext): rizu.editor.EditorViewState
---@field getOverlayTabs fun(self: rizu.editor.EditorOverlayShellContext): string[]
---@field isResourcesLoaded fun(self: rizu.editor.EditorOverlayShellContext): boolean

---@class rizu.editor.EditorOverlayShellService
---@operator call: rizu.editor.EditorOverlayShellService
local EditorOverlayShellService = class()

---@param context rizu.editor.EditorOverlayShellContext
---@return rizu.editor.EditorOverlayShellState
function EditorOverlayShellService:getState(context)
	return {
		activeTab = context:getViewState():getOverlayState(),
		tabs = context:getOverlayTabs(),
		resourcesLoaded = context:isResourcesLoaded(),
	}
end

---@param context rizu.editor.EditorOverlayShellContext
---@param input rizu.editor.EditorOverlayShellInput
function EditorOverlayShellService:handleInput(context, input)
	context:getViewState():setOverlayState(input.activeTab)
end

return EditorOverlayShellService
