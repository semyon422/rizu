local Screen = require("gui.Screen")
local ModalManager = require("ui.ModalManager")
local FpsView = require("ui.views.FpsView")
local CacheProgressView = require("ui.views.CacheProgressView")
local PopupContainer = require("ui.views.PopupContainer")
local UiActions = require("ui.UiActions")
local Settings = require("rizu.config.Settings")

---@class ui.Overlay : gui.Screen
---@operator call: ui.Overlay
---@field modal_manager ui.ModalManager
---@field fps_view ui.views.FpsView
---@field popup_container ui.views.PopupContainer
---@field ui ui.UserInterface
---@field cache_progress_view ui.views.CacheProgressView
local Overlay = Screen + {}

local MASTER_VOLUME_STEP = 0.05

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
	-- Popups are last so they draw and receive input above modal contents.
	self.popup_container = self.root:add(PopupContainer())
end

---@param event {name: string, time: number, [integer]: any}
---@param modifiers gui.ModifierKeys?
---@return boolean handled
function Overlay:receive(event, modifiers)
	local inputs = self.inputs
	if not inputs then return false end
	local keyboard_action = inputs:isActionJustPressed(UiActions.command_palette)
		or inputs:isActionJustPressed(UiActions.open_config)
	local volume_action = inputs:isActionJustPressed(UiActions.master_volume_increase)
		or inputs:isActionJustPressed(UiActions.master_volume_decrease)
	-- Actions are applied during update, after the input queue is drained.
	return keyboard_action and (event.name == "keypressed" or event.name == "textinput")
		or volume_action and event.name == "wheelmoved"
end

---@param inputs gui.Inputs
function Overlay:onHandleInputs(inputs)
	local settings = self.ui.game.settings
	local volume_key = Settings.keys.audio.volume_master
	if inputs:consumeActionJustPressed(UiActions.master_volume_increase) then
		settings:setNumber(volume_key, math.min(1, settings:getNumber(volume_key) + MASTER_VOLUME_STEP))
	elseif inputs:consumeActionJustPressed(UiActions.master_volume_decrease) then
		settings:setNumber(volume_key, math.max(0, settings:getNumber(volume_key) - MASTER_VOLUME_STEP))
	elseif inputs:consumeActionJustPressed(UiActions.command_palette) then
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
