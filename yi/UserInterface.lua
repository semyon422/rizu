local IUserInterface = require("sphere.IUserInterface")
local Inputs = require("ui.input.Inputs")
local Resources = require("yi.Resources")
local Painter = require("yi.Painter")
local table_util = require("table_util")

local MenuBackground = require("yi.layers.MenuBackground")
local MainMenu = require("yi.layers.MainMenu")
local Multiplayer = require("yi.layers.Multiplayer")
local Config = require("yi.layers.Config")
local Select = require("yi.layers.Select")

---@class yi.UserInterface : sphere.IUserInterface
---@overload fun(game: sphere.GameController): yi.UserInterface
---@field current_layer yi.Layer?
local UserInterface = IUserInterface + {}

local MAX_DT = 1 / 30
local TARGET_WIDTH = 1920
local TARGET_HEIGHT = 1080

---@param game sphere.GameController
function UserInterface:new(game)
	self.game = game

	self.resources = Resources()
	self.inputs = Inputs()
	---@type ui.ModifierKeys
	self.modifiers = {control = false, alt = false, shift = false, super = false}
end

function UserInterface:load()
	self.resources:load()
	Painter.setAtlas(self.resources.atlas)
	Painter.setScale(1)

	self.menu_background = MenuBackground(self)
	self.config = Config(self)
	self.multiplayer = Multiplayer(self)
	self.select = Select(self)
	self.main_menu = MainMenu(self)

	---@type yi.Layer[]
	self.layers = {
		-- self.chart_background,
		self.select,
		self.menu_background,
		self.config,
		self.multiplayer,
		self.main_menu
	}

	self:transitTo(self.main_menu)
end

---@param layer yi.Layer
function UserInterface:transitTo(layer)
	if self.current_layer then
		self.current_layer:exit()
		self.previous_layer = self.current_layer
	end

	if
		layer == self.main_menu or
		layer == self.config or
		layer == self.multiplayer
	then
		self.menu_background:enter()
	else
		self.menu_background:exit()
	end

	self.current_layer = layer
	layer:enter()
end

---@param dt number
function UserInterface:update(dt)
	dt = math.min(dt, MAX_DT)

	if self:dimensionsChanged() then
		local w, h = love.graphics.getDimensions()
		local layout_scale = math.min(h / TARGET_HEIGHT, w / TARGET_WIDTH)
		Painter.setScale(layout_scale)
		for _, v in pairs(self.layers) do
			v:updateDimensions(w, h, layout_scale)
		end
	end

	self.modifiers.control = love.keyboard.isDown("lctrl", "rctrl")
	self.modifiers.alt = love.keyboard.isDown("lalt", "ralt")
	self.modifiers.shift = love.keyboard.isDown("lshift", "rshift")

	self.inputs:beginFrame(love.mouse.getPosition())

	for _, v in ipairs(self.layers) do
		if v:isVisible() then
			v:update(dt)
		end
	end

	for i = #self.layers, 1, -1 do
		local v = self.layers[i]

		if v:isTakingInputs() then
			v:acceptInputs(self.inputs)
		end
	end
end

function UserInterface:draw()
	for _, v in ipairs(self.layers) do
		if v:isVisible() then
			v:draw()
		end
	end
end

function UserInterface:dimensionsChanged()
	local ww, wh = love.graphics.getDimensions()
	local pw, ph = self.prev_w, self.prev_h
	self.prev_w, self.prev_h = ww, wh
	return ww ~= pw or wh ~= ph
end

---@param event table
function UserInterface:receive(event)
	self.inputs:receive(event, self.modifiers)

	for _, v in ipairs(self.layers) do
		if v:isTakingInputs() then
			v:receive(event)
		end
	end
end

return UserInterface
