local View = require("gui.View")
local EditorWidgets = require("yi.views.editor.EditorWidgets")
local gfx_util = require("gfx_util")
local spherefonts = require("sphere.assets.fonts")
local EditorAudioOverlayPanel = require("yi.views.editor.EditorAudioOverlayPanel")
local EditorBmsOverlayPanel = require("yi.views.editor.EditorBmsOverlayPanel")
local EditorInfoOverlayPanel = require("yi.views.editor.EditorInfoOverlayPanel")
local EditorNotesOverlayPanel = require("yi.views.editor.EditorNotesOverlayPanel")
local EditorOverlayPanel = require("yi.views.editor.EditorOverlayPanel")
local EditorTimingOverlayPanel = require("yi.views.editor.EditorTimingOverlayPanel")

local EditorLayout = require("yi.views.editor.EditorLayout")

---@class yi.views.editor.EditorOverlayView: gui.View
---@operator call: yi.views.editor.EditorOverlayView
---@field screen table
---@field panel yi.views.editor.EditorOverlayPanel
---@field widgets yi.views.editor.EditorWidgets
---@field infoPanel yi.views.editor.EditorInfoOverlayPanel
---@field audioPanel yi.views.editor.EditorAudioOverlayPanel
---@field bmsPanel yi.views.editor.EditorBmsOverlayPanel
---@field notesPanel yi.views.editor.EditorNotesOverlayPanel
---@field timingPanel yi.views.editor.EditorTimingOverlayPanel
---@field tabDrawers {[string]: string}
local EditorOverlayView = View + {}

EditorOverlayView.tabDrawers = {
	info = "drawInfoTab",
	audio = "drawAudioTab",
	timings = "drawTimingsTab",
	notes = "drawNotesTab",
	bms = "drawBmsTab",
}

---@param screen table
function EditorOverlayView:new(screen)
	View.new(self)
	self.screen = screen
	self.panel = EditorOverlayPanel()
	self.widgets = EditorWidgets()
	self.infoPanel = EditorInfoOverlayPanel()
	self.audioPanel = EditorAudioOverlayPanel()
	self.bmsPanel = EditorBmsOverlayPanel()
	self.notesPanel = EditorNotesOverlayPanel()
	self.timingPanel = EditorTimingOverlayPanel()
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self:setSize(love.graphics.getDimensions())
end

function EditorOverlayView:load()
	self:setSize(love.graphics.getDimensions())
end

---@param screen_x number
---@param screen_y number
---@return boolean
function EditorOverlayView:isMouseOver(screen_x, screen_y)
	return self.panel:containsPoint(screen_x, screen_y)
end

---@param e gui.MouseDownEvent
function EditorOverlayView:onMouseDown(e)
	return self.panel:onMouseDown(e)
end

---@param e gui.MouseUpEvent
function EditorOverlayView:onMouseUp(e)
	return self.panel:onMouseUp(e)
end

---@param e gui.DragEvent
function EditorOverlayView:onDrag(e)
	return self.panel:onDrag(e)
end

---@param e gui.DragEndEvent
function EditorOverlayView:onDragEnd(e)
	return self.panel:onDragEnd(e)
end

---@param e gui.KeyDownEvent
function EditorOverlayView:onKeyDown(e)
	return self.panel:onKeyDown(e)
end

---@param e gui.TextInputEvent
function EditorOverlayView:onTextInput(e)
	return self.panel:onTextInput(e)
end

---@return rizu.editor.EditorViewContext
function EditorOverlayView:getOverlayContext()
	return self.screen.game.editorModel.context:getViewContext()
end

---@return rizu.editor.EditorBmsOverlayContext
function EditorOverlayView:getBmsOverlayContext()
	local overlayContext = self:getOverlayContext()
	return self.screen.editorViewServices.overlayContextFactory:createBmsOverlayContext(self.screen, overlayContext)
end

---@return rizu.editor.EditorInfoOverlayContext
function EditorOverlayView:getInfoOverlayContext()
	local overlayContext = self:getOverlayContext()
	return self.screen.editorViewServices.overlayContextFactory:createInfoOverlayContext(self.screen, overlayContext)
end

function EditorOverlayView:drawInfoTab()
	self.infoPanel:draw(self.screen, self.panel, self:getInfoOverlayContext())
end

function EditorOverlayView:drawAudioTab()
	self.audioPanel:draw(self.screen, self.panel, self:getOverlayContext())
end

function EditorOverlayView:drawTimingsTab()
	self.timingPanel:draw(self.screen, self.panel, self:getOverlayContext())
end

function EditorOverlayView:drawNotesTab()
	self.notesPanel:draw(self.screen, self.panel, self:getOverlayContext())
end

function EditorOverlayView:drawBmsTab()
	self.bmsPanel:draw(self.screen, self.panel, self:getBmsOverlayContext())
end

---@param activeTab string
function EditorOverlayView:drawActiveTab(activeTab)
	local methodName = self.tabDrawers[activeTab]
	if methodName then
		self[methodName](self)
	end
end

---@param resourcesLoaded boolean
function EditorOverlayView:drawLoading(resourcesLoaded)
	if resourcesLoaded then
		return
	end

	local w, h = EditorLayout:move("base")
	love.graphics.setColor(1, 1, 1, 0.5)
	love.graphics.setFont(spherefonts.get("Noto Sans", 160))
	gfx_util.printFrame("loading", 0, 0, w, h, "center", "center")
end

function EditorOverlayView:draw()
	local screen = self.screen
	local _, h = EditorLayout:move("base")
	local overlayContext = self:getOverlayContext()
	local overlayShellService = screen.editorViewServices.overlayShellService
	local state = overlayShellService:getState(overlayContext)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
	love.graphics.setLineStyle("smooth")

	local activeTab = self.panel:tabs("editor overlay tabs", state.activeTab, state.tabs, 0, 0, 400, 55)
	overlayShellService:handleInput(overlayContext, {
		activeTab = activeTab,
	})

	self.widgets:panelBackground(0, 55, 420, h - 55)
	love.graphics.setColor(1, 1, 1, 1)
	self.panel:reset()
	self:drawActiveTab(activeTab)
	self:drawLoading(state.resourcesLoaded)
	self.panel:finishFrame()
end

return EditorOverlayView
