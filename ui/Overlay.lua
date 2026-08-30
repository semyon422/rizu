local decibel = require("decibel")
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
local MASTER_VOLUME_DECIBEL_STEP = 1
local MIN_VOLUME_DECIBELS = -60

---@param settings rizu.config.Config
---@param direction -1|1
local function adjustMasterVolume(settings, direction)
	local keys = Settings.keys.audio
	local volume = settings:getNumber(keys.volume_master)
	if settings:getChoice(keys.volume_type) == "logarithmic" then
		if volume == 0 and direction < 0 then
			return
		end
		local decibels = math.max(MIN_VOLUME_DECIBELS, decibel.f_to_lf(volume))
		local adjusted = math.max(MIN_VOLUME_DECIBELS, math.min(0, decibels + direction * MASTER_VOLUME_DECIBEL_STEP))
		volume = decibel.lf_to_f(adjusted)
	else
		volume = math.max(0, math.min(1, volume + direction * MASTER_VOLUME_STEP))
	end
	settings:setNumber(keys.volume_master, volume)
end

---@param ui ui.UserInterface
function Overlay:new(ui)
	Screen.new(self)
	self.ui = ui
	self.fps_view = self.root:add(FpsView(ui.config))
	self.fps_view:setAlignment(1, 1)
	self.fps_view:setOffset(-16, -16)
	self.cache_progress_view = self.root:add(CacheProgressView(ui.game.library))
	self.cache_progress_view:setOffset(16, 16)
	self.popup_container = PopupContainer()
	self.modal_manager = self.root:add(ModalManager(ui, self.popup_container))
	-- Popups are last so they draw and receive input above modal contents.
	self.root:add(self.popup_container)
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
	if inputs:consumeActionJustPressed(UiActions.master_volume_increase) then
		adjustMasterVolume(settings, 1)
	elseif inputs:consumeActionJustPressed(UiActions.master_volume_decrease) then
		adjustMasterVolume(settings, -1)
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
