local IUserInterface = require("sphere.IUserInterface")
local Inputs = require("ui.input.Inputs")
local Resources = require("yi.Resources")
local Menus = require("yi.Menus")
local ChartMenus = require("yi.ChartMenus")
local Painter = require("yi.Painter")

---@class yi.UserInterface : sphere.IUserInterface
---@overload fun(game: sphere.GameController): yi.UserInterface
---@field modifiers ui.ModifierKeys
---@field current_screen string?
---@field previous_screen string?
local UserInterface = IUserInterface + {}

local MAX_DT = 1 / 30
local TARGET_WIDTH = 1920
local TARGET_HEIGHT = 1080

---@param game sphere.GameController
function UserInterface:new(game)
	self.game = game

	local ww, wh = love.graphics.getDimensions()
	self.prev_w, self.prev_h = ww, wh

	self.resources = Resources()
	self.resources:load()
	self.inputs = Inputs()
	self.modifiers = {control = false, alt = false, shift = false, super = false}
end

function UserInterface:load()
	love.keyboard.setKeyRepeat(true)
	self:buildUI()
end

function UserInterface:buildUI()
	local w, h = love.graphics.getDimensions()
	self.menus = Menus(self, w, h)
	self.chart_menus = ChartMenus(self, w, h)

	local screen = self.current_screen or "main_menu"

	if self.menus:hasScreen(screen) then
		self.menus.visiblity:snap(1)
	else
		self.menus.visiblity:snap(0)
	end

	self:setScreen(screen)
end

---@param screen string
function UserInterface:setScreen(screen)
	self.previous_screen = self.current_screen

	if self.menus:hasScreen(screen) then
		self.menus:setScreen(screen)
		print("hello?")
	elseif self.chart_menus:hasScreen(screen) then
		self.menus:hide()
		self.chart_menus:setScreen(screen)
	else
		error("Screen doesn't exist")
	end

	self.current_screen = screen
end

---@param dt number
function UserInterface:update(dt)
	if self:windowDimensionsChanged() then
		self:buildUI()
	end

	self.modifiers.control = love.keyboard.isDown("lctrl", "rctrl")
	self.modifiers.alt = love.keyboard.isDown("lalt", "ralt")
	self.modifiers.shift = love.keyboard.isDown("lshift", "rshift")

	self.inputs:beginFrame(love.mouse.getPosition())

	self.chart_menus:update(dt)
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

	local s = self.current_screen

	if s == "main_menu" or s == "config" then
		self.menus:receive(event)
	elseif s == "select" or s == "gameplay" then
		self.chart_menus:receive(event)
	end
end

return UserInterface
