local IUserInterface = require("sphere.IUserInterface")
local Inputs = require("ui.input.Inputs")
local Resources = require("yi.Resources")
local Painter = require("yi.Painter")
local table_util = require("table_util")

local MenuBackground = require("yi.layers.MenuBackground")
local MainMenu = require("yi.layers.MainMenu")
local Multiplayer = require("yi.layers.Multiplayer")
local Config = require("yi.layers.Config")

---@class yi.UserInterface : sphere.IUserInterface
---@overload fun(game: sphere.GameController): yi.UserInterface
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

	self.layers = {
		menu_background = MenuBackground(self),
		config = Config(self),
		multiplayer = Multiplayer(self),
		main_menu = MainMenu(self)
	}

	self.visible = {}
	self:transitTo("main_menu")
end

---@param layer "main_menu" | "config" | "multiplayer" | "dlc"
function UserInterface:transitTo(layer)
	table_util.clear(self.visible)

	if layer == "main_menu" then
		table.insert(self.visible, self.layers.menu_background)
		table.insert(self.visible, self.layers.main_menu)
	elseif layer == "multiplayer" then
		table.insert(self.visible, self.layers.menu_background)
		table.insert(self.visible, self.layers.multiplayer)
	elseif layer == "config" then
		table.insert(self.visible, self.layers.menu_background)
		table.insert(self.visible, self.layers.config)
	end
end

---@param dt number
function UserInterface:update(dt)
	dt = math.min(dt, MAX_DT)

	if self:dimensionsChanged() then
		local w, h = love.graphics.getDimensions()
		local layout_scale = math.min(h / TARGET_HEIGHT, w / TARGET_WIDTH)
		local ui_scale = layout_scale
		Painter.setScale(ui_scale)
		for _, v in pairs(self.layers) do
			v:updateDimensions(w, h, layout_scale, ui_scale)
		end
	end

	self.modifiers.control = love.keyboard.isDown("lctrl", "rctrl")
	self.modifiers.alt = love.keyboard.isDown("lalt", "ralt")
	self.modifiers.shift = love.keyboard.isDown("lshift", "rshift")

	self.inputs:beginFrame(love.mouse.getPosition())

	for _, v in ipairs(self.visible) do
		v:update(dt)
	end

	for i = #self.visible, 1, -1 do
		self.visible[i]:acceptInputs(self.inputs)
	end
end

function UserInterface:draw()
	for _, v in ipairs(self.visible) do
		v:draw()
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
	self.visible[#self.visible]:receive(event)
end

return UserInterface
