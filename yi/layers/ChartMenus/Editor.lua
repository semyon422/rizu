local Screen = require("yi.Screen")
local Layout = require("ui.views.EditorView.Layout")
local EditorViewConfig = require("ui.views.EditorView.EditorViewConfig")
local EditorViewOverlay = require("ui.views.EditorView.EditorViewOverlay")
local Footer = require("ui.views.EditorView.Footer")
local Foreground = require("ui.views.EditorView.Foreground")
local WaveformView = require("ui.views.EditorView.WaveformView")
local OnsetsView = require("ui.views.EditorView.OnsetsView")
local OnsetsDistView = require("ui.views.EditorView.OnsetsDistView")
local gfx_util = require("gfx_util")
local just = require("just")
local thread = require("thread")
local EditorScreenLoadService = require("rizu.editor.EditorScreenLoadService")

---@class yi.layers.Editor : yi.Screen
---@operator call: yi.layers.Editor
local Editor = Screen + {}

---@param yi yi.UserInterface
function Editor:new(yi)
	Screen.new(self)
	self.yi = yi
	self.game = yi.game
	self.editorScreenLoadService = EditorScreenLoadService()
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
	if not self.editor_loaded then
		return
	end

	love.graphics.replaceTransform(gfx_util.transform(self.transform))
	self.game.editorModel:update()
	self.sequence_view:update(dt)
end

function Editor:draw()
	if not self.editor_loaded then
		return
	end

	just.container("yi editor screen", true)

	Layout:draw()
	EditorViewConfig(self)
	self.sequence_view:draw()
	self.snap_grid_view:draw()
	WaveformView(self)
	OnsetsView(self)
	OnsetsDistView(self)
	Footer(self)
	EditorViewOverlay(self)
	Foreground(self)

	just.container()
end

---@param event table
function Editor:receive(event)
	if not self.editor_loaded then
		return
	end

	self.game.editorController:receive(event)
	self.sequence_view:receive(event)
	Screen.receive(self, event)
end

return Editor
