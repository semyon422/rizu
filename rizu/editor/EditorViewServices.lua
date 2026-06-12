local class = require("class")
local EditorActionService = require("rizu.editor.EditorActionService")
local EditorOverlayActionService = require("rizu.editor.EditorOverlayActionService")
local EditorScrollInputService = require("rizu.editor.EditorScrollInputService")

---@class rizu.editor.EditorViewServicesDeps
---@field actionService rizu.editor.EditorActionService?
---@field overlayActionService rizu.editor.EditorOverlayActionService?
---@field scrollInputService rizu.editor.EditorScrollInputService?

---@class rizu.editor.EditorViewServices
---@operator call: rizu.editor.EditorViewServices
---@field actionService rizu.editor.EditorActionService
---@field overlayActionService rizu.editor.EditorOverlayActionService
---@field scrollInputService rizu.editor.EditorScrollInputService
local EditorViewServices = class()

---@param deps rizu.editor.EditorViewServicesDeps?
function EditorViewServices:new(deps)
	deps = deps or {}
	self.actionService = deps.actionService or EditorActionService()
	self.overlayActionService = deps.overlayActionService or EditorOverlayActionService()
	self.scrollInputService = deps.scrollInputService or EditorScrollInputService()
end

return EditorViewServices
