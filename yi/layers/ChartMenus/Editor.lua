local Screen = require("gui.Screen")
local thread = require("thread")
local EditorScreenFrameService = require("rizu.editor.EditorScreenFrameService")
local EditorScreenLoadService = require("rizu.editor.EditorScreenLoadService")

---@class yi.layers.Editor : gui.Screen
---@operator call: yi.layers.Editor
local Editor = Screen + {}

---@param yi yi.UserInterface
function Editor:new(yi)
	Screen.new(self)
	self.yi = yi
	self.game = yi.game
	self.editorScreenLoadService = EditorScreenLoadService()
	self.editorScreenFrameService = EditorScreenFrameService()
	self.editor_loaded = false
	self.loading = false
end

function Editor:enter()
	if self.loading or self.editor_loaded then
		return
	end

	thread.coro(function()
		self.editorScreenLoadService:enter(self)
	end)()
end

function Editor:handleKeyDown(key)
	if key == "escape" then
		self.yi:setScreen("select")
	else
		return false
	end

	return true
end

function Editor:exit()
	self.editorScreenLoadService:exit(self)
end

---@param dt number
function Editor:update(dt)
	self.editorScreenFrameService:update(self, dt)
end

function Editor:draw()
	self.editorScreenFrameService:draw(self)
end

---@param event table
function Editor:receive(event)
	self.editorScreenFrameService:receive(self, event)
end

return Editor
