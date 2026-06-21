local IUserInterface = require("sphere.IUserInterface")
local Inputs = require("gui.input.Inputs")
local Resources = require("yi.Resources")
local Painter = require("yi.Painter")
local Select = require("yi.layers.Select")
local Gameplay =  require("yi.layers.Gameplay")
local Modals = require("yi.layers.Modals")
local Overlay = require("yi.layers.Overlay")
local SettingsScheme = require("rizu.config.schemas.Settings")
local Colors = require("yi.Colors")
local delay = require("delay")

local Registry = require("yi.command_palette.Registry")
local PaletteState = require("yi.command_palette.PaletteState")
local GlobalCommands = require("yi.command_palette.GlobalCommands")

---@class yi.UserInterface : sphere.IUserInterface
---@overload fun(game: sphere.GameController): yi.UserInterface
---@field modifiers gui.ModifierKeys
---@field layers gui.Layer[]
---@field next_screen gui.Screen?
---@field current_screen gui.Screen?
---@field previous_screen gui.Screen?
---@field screens {[string]: gui.Screen}
---@field command_registry yi.command_palette.Registry
---@field command_palette yi.command_palette.PaletteState
local UserInterface = IUserInterface + {}

local TARGET_HEIGHT = 1080

---@param game sphere.GameController
function UserInterface:new(game)
	self.game = game

	local ww, wh = love.graphics.getDimensions()
	self.prev_w, self.prev_h = ww, wh

	Resources.load()
	Painter.init()
	self.inputs = Inputs()
	self.modifiers = {control = false, alt = false, shift = false, super = false}

	self.screens = {}

	self.command_registry = Registry()
	for _, cmd in ipairs(GlobalCommands.get(game)) do
		self.command_registry:registerGlobal(cmd)
	end
	self.command_palette = PaletteState(self.command_registry)
end

function UserInterface:load()
	self.game.settings_config.onChanged:add(self)

	local h = love.graphics.getHeight()
	local scale = h / TARGET_HEIGHT
	Resources.setUIScale(scale)
	Resources.setFontScale(1)

	self.modals = Modals(self)
	self.overlay = Overlay(self)

	self.modals.ui_scale = scale
	self.overlay.ui_scale = scale

	self.modals:load()
	self.overlay:load()

	self.screens = {
		select = Select(self),
		gameplay = Gameplay(self)
	}

	for _, v in pairs(self.screens) do
		v.ui_scale = scale
		v:load()
	end

	love.keyboard.setKeyRepeat(true)
	love.keyboard.setTextInput(true)
	self:setScreen("select")
end

function UserInterface:unload()
	self.modals:unload()
	self.overlay:unload()
end

---@param screen_name string
function UserInterface:setScreen(screen_name)
	self.previous_screen = self.current_screen
	self.next_screen = self.screens[screen_name]
end

function UserInterface:transitToNextScreen()
	if not self.next_screen then
		return
	end

	self.previous_screen = self.current_screen
	self.current_screen = self.next_screen
	self.next_screen = nil

	if self.previous_screen then
		self.previous_screen:exit()
	end

	self.current_screen:enter()
end

function UserInterface:reload()
	self:unload()
	self:load()
end

---@param dt number
function UserInterface:update(dt)
	if self:windowDimensionsChanged() then
		delay.debounce(self, "yi_window_dimensions_changed", 0.2, self.reload, self)
	end

	if self.next_screen then
		self:transitToNextScreen()
	end

	self.modifiers.control = love.keyboard.isDown("lctrl", "rctrl")
	self.modifiers.alt = love.keyboard.isDown("lalt", "ralt")
	self.modifiers.shift = love.keyboard.isDown("lshift", "rshift")

	self.inputs:beginFrame(love.mouse.getPosition())

	self.modals:acceptInputs(self.inputs)
	self.overlay:acceptInputs(self.inputs)

	self.modals:update(dt)
	self.overlay:update(dt)

	if self.current_screen then
		self.current_screen:acceptInputs(self.inputs)
		self.current_screen:update(dt)
	end
end

function UserInterface:draw()
	love.graphics.clear(Colors.background)

	if self.current_screen then
		self.current_screen:draw()
	end

	self.modals:draw()
	self.overlay:draw()
end

function UserInterface:windowDimensionsChanged()
	local ww, wh = love.graphics.getDimensions()
	local pw, ph = self.prev_w, self.prev_h
	self.prev_w, self.prev_h = ww, wh
	return ww ~= pw or wh ~= ph
end

---@param event table
function UserInterface:receive(event)
	self.inputs:receive(event, self.modifiers)

	if event.type == "config_commit" then
		local ui = SettingsScheme.graphics.appearance.user_interface
		if event[1] == ui then
			local name = self.game.settings_config:getString(ui)
			if name then
				self.game.uiModel:setUserInterface(name)
				self.game.uiModel:loadSelected()
				return
			end
		end
	end
end

return UserInterface
