local class = require("class")
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

---@alias rizu.editor.EditorScreenDrawFunc fun(screen: table)

---@class rizu.editor.EditorScreenFrameServiceDeps
---@field layout table?
---@field editorViewConfig rizu.editor.EditorScreenDrawFunc?
---@field waveformView rizu.editor.EditorScreenDrawFunc?
---@field onsetsView rizu.editor.EditorScreenDrawFunc?
---@field onsetsDistView rizu.editor.EditorScreenDrawFunc?
---@field footer rizu.editor.EditorScreenDrawFunc?
---@field editorViewOverlay rizu.editor.EditorScreenDrawFunc?
---@field foreground rizu.editor.EditorScreenDrawFunc?
---@field container fun(id: string?, active: boolean?)?
---@field transform fun(transform: any): any?
---@field graphics table?
---@field baseScreen table?

---@class rizu.editor.EditorScreenFrameService
---@operator call: rizu.editor.EditorScreenFrameService
local EditorScreenFrameService = class()

---@param deps rizu.editor.EditorScreenFrameServiceDeps?
function EditorScreenFrameService:new(deps)
	deps = deps or {}
	self.layout = deps.layout or Layout
	self.editorViewConfig = deps.editorViewConfig or EditorViewConfig
	self.waveformView = deps.waveformView or WaveformView
	self.onsetsView = deps.onsetsView or OnsetsView
	self.onsetsDistView = deps.onsetsDistView or OnsetsDistView
	self.footer = deps.footer or Footer
	self.editorViewOverlay = deps.editorViewOverlay or EditorViewOverlay
	self.foreground = deps.foreground or Foreground
	self.container = deps.container or just.container
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

	self.graphics.replaceTransform(self.transform(screen.transform))
	screen.game.editorModel:update()
	screen.sequence_view:update(dt)
	return true
end

---@param screen table
---@return boolean drawn
function EditorScreenFrameService:draw(screen)
	if not screen.editor_loaded then
		return false
	end

	self.container("yi editor screen", true)

	self.layout:draw()
	self.editorViewConfig(screen)
	screen.sequence_view:draw()
	screen.snap_grid_view:draw()
	self.waveformView(screen)
	self.onsetsView(screen)
	self.onsetsDistView(screen)
	self.footer(screen)
	self.editorViewOverlay(screen)
	self.foreground(screen)

	self.container()
	return true
end

---@param screen table
---@param event table
---@return boolean received
function EditorScreenFrameService:receive(screen, event)
	if not screen.editor_loaded then
		return false
	end

	screen.game.editorController:receive(event)
	screen.sequence_view:receive(event)
	self.baseScreen.receive(screen, event)
	return true
end

return EditorScreenFrameService
