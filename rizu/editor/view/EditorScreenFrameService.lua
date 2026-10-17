local class = require("class")
local Screen = require("gui.Screen")
local gfx_util = require("gfx_util")

---@class rizu.editor.EditorScreenFrameServiceDeps
---@field layout table?
---@field transform fun(transform: any): any?
---@field graphics table?
---@field baseScreen table?

---@class rizu.editor.EditorScreenFrameService
---@operator call: rizu.editor.EditorScreenFrameService
local EditorScreenFrameService = class()

---@param deps rizu.editor.EditorScreenFrameServiceDeps
function EditorScreenFrameService:new(deps)
	self.layout = assert(deps.layout, "editor layout dependency is required")
	self.transform = deps.transform or gfx_util.transform
	self.graphics = deps.graphics or love.graphics
	self.baseScreen = deps.baseScreen or Screen
end

---@param screen table
---@param dt number
---@return boolean updated
function EditorScreenFrameService:update(screen, dt)
	if not screen.editor_loaded then
		return false
	end

	self.graphics.push("all")
	self.graphics.replaceTransform(self.transform(screen.transform))
	screen.game.editorModel:update()
	self.graphics.pop()
	if self.baseScreen.update then
		self.baseScreen.update(screen, dt)
	end
	return true
end

---@param screen table
---@return boolean drawn
function EditorScreenFrameService:draw(screen)
	if not screen.editor_loaded then
		return false
	end

	self.layout:update(self.graphics)
	self.baseScreen.draw(screen)
	return true
end

---@param screen table
---@param event table
---@return boolean received
function EditorScreenFrameService:receive(screen, event)
	if not screen.editor_loaded then
		return false
	end

	if screen.editor_snap_grid_view then
		screen.editor_snap_grid_view:receive(event)
	end
	if screen.editor_playfield_view then
		screen.editor_playfield_view:receive(event)
	end
	screen.game.editorController:receive(event)
	screen.editor_sequence_view:receive(event)
	self.baseScreen.receive(screen, event)
	return true
end

return EditorScreenFrameService
