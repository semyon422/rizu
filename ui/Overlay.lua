local Screen = require("gui.Screen")
local ModalManager = require("ui.ModalManager")
local FpsView = require("ui.views.FpsView")
local CacheProgressView = require("ui.views.CacheProgressView")
local UiActions = require("ui.UiActions")

---@class ui.Overlay : gui.Screen
---@operator call: ui.Overlay
---@field modal_manager ui.ModalManager
---@field fps_view ui.views.FpsView
---@field ui ui.UserInterface
---@field cache_progress_view ui.views.CacheProgressView
local Overlay = Screen + {}

---@param ui ui.UserInterface
function Overlay:new(ui)
	Screen.new(self)
	self.ui = ui
	self.fps_view = self.root:add(FpsView(ui.config))
	self.fps_view:setAlignment(1, 1)
	self.fps_view:setOffset(-16, -16)
	self.cache_progress_view = self.root:add(CacheProgressView(ui.game.library))
	self.cache_progress_view:setOffset(16, 16)
	self.modal_manager = self.root:add(ModalManager(ui))
end

---@param event {name: string, time: number, [integer]: any}
---@param modifiers gui.ModifierKeys?
---@return boolean handled
function Overlay:receive(event, modifiers)
	local inputs = self.inputs
	if not inputs then return false end
	local global_action = inputs:isActionJustPressed(UiActions.command_palette)
		or inputs:isActionJustPressed(UiActions.open_config)
	-- Consume both the shortcut key and the text event it may produce. The
	-- action itself is applied during update, after the input queue is drained.
	return global_action and (event.name == "keypressed" or event.name == "textinput")
end

---@param inputs gui.Inputs
function Overlay:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.command_palette) then
		self.modal_manager:attachPalette()
	elseif inputs:consumeActionJustPressed(UiActions.open_config) then
		self.modal_manager:attachConfig()
	elseif inputs:consumeActionJustPressed(UiActions.global_screenshot_open) then
		self.ui.game.app.screenshotModel:capture(true)
	elseif inputs:consumeActionJustPressed(UiActions.global_screenshot) then
		self.ui.game.app.screenshotModel:capture(false)
	end
end

return Overlay
