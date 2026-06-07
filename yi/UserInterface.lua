local IUserInterface = require("sphere.IUserInterface")
local Inputs = require("gui.input.Inputs")
local Resources = require("yi.Resources")
local Menus = require("yi.layers.Menus.Menus")
local ChartMenus = require("yi.layers.ChartMenus.ChartMenus")
local SettingsScheme = require("rizu.config.schemas.Settings")

---@class yi.UserInterface : sphere.IUserInterface
---@overload fun(game: sphere.GameController): yi.UserInterface
---@field modifiers gui.ModifierKeys
---@field layers yi.Layer[]
---@field next_screen string?
---@field current_screen string?
---@field previous_screen string?
---@field current_layer yi.ScreenContainer
---@field screens {[string]: {layer: yi.ScreenContainer, screen: yi.Screen}}
local UserInterface = IUserInterface + {}

local MAX_DT = 1 / 30
local TARGET_WIDTH = 1920
local TARGET_HEIGHT = 1080

---@param game sphere.GameController
function UserInterface:new(game)
	self.game = game

	local ww, wh = love.graphics.getDimensions()
	self.prev_w, self.prev_h = ww, wh

	Resources.load()
	self.inputs = Inputs()
	self.modifiers = {control = false, alt = false, shift = false, super = false}
	self.layers = {}
end

function UserInterface:load()
	self.game.settings_config.onChanged:add(self)

	local w, h = love.graphics.getDimensions()
	local scale = math.min(1, math.min(w / TARGET_WIDTH, h / TARGET_HEIGHT))
	Resources.setFontScale(scale)

	self.chart_menus = ChartMenus(self)
	self.menus = Menus(self)

	self.chart_menus:load()
	self.menus:load()

	self.current_layer = self.menus

	self.screens = {
		main_menu = {layer = self.menus, screen = self.menus.main_menu},
		config = {layer = self.menus, screen = self.menus.config},
		select = {layer = self.chart_menus, screen = self.chart_menus.select},
		chart_loading = {layer = self.chart_menus, screen = self.chart_menus.chart_loading},
		gameplay = {layer = self.chart_menus, screen = self.chart_menus.gameplay},
		result = {layer = self.chart_menus, screen = self.chart_menus.result},
	}

	love.keyboard.setKeyRepeat(true)
end

function UserInterface:unload()
	self.game.settings_config.onChanged:remove(self)
	self.chart_menus:unload()
	self.menus:unload()
end

---@param screen string
function UserInterface:setScreen(screen)
	self.previous_screen = self.current_screen
	self.next_screen = screen
end

function UserInterface:transitToNextScreen()
	local screen_name = self.next_screen
	self.current_screen = screen_name
	self.next_screen = nil

	if not screen_name then
		return
	end

	local config = self.screens[screen_name]

	if not config then
		return
	end

	local next_layer = config.layer
	local next_screen = config.screen

	local current_layer = self.current_layer

	if current_layer and current_layer.current_screen then
		current_layer.current_screen:exit()
	end

	if next_layer == self.menus then
		self.menus:show()
	else
		self.menus:hide()
	end

	next_layer.current_screen = next_screen
	self.current_layer = next_layer
	next_screen:enter()
end

---@param dt number
function UserInterface:update(dt)
	if self:windowDimensionsChanged() then
		self:unload()
		self:load()
	end

	if self.next_screen then
		self:transitToNextScreen()
	end

	self.modifiers.control = love.keyboard.isDown("lctrl", "rctrl")
	self.modifiers.alt = love.keyboard.isDown("lalt", "ralt")
	self.modifiers.shift = love.keyboard.isDown("lshift", "rshift")

	self.inputs:beginFrame(love.mouse.getPosition())

	if self.current_layer then
		self.current_layer:acceptInputs(self.inputs)
	end

	if self.menus.visiblity:get() < 1 then
		self.chart_menus:update(dt)
	end
	self.menus:update(dt)
end

function UserInterface:draw()
	if self.menus.visiblity:get() < 1 then
		self.chart_menus:draw()
	end
	if self.menus:isVisible() then
		self.menus:draw()
	end
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

	self.menus:receive(event)
	self.chart_menus:receive(event)
end

return UserInterface
