local IUserInterface = require("sphere.IUserInterface")
local Inputs = require("ui.input.Inputs")
local Resources = require("yi.Resources")
local Painter = require("yi.Painter")
local ScreenComposition = require("yi.ScreenComposition")

---@class yi.UserInterface : sphere.IUserInterface
---@overload fun(game: sphere.GameController): yi.UserInterface
---@field modifiers ui.ModifierKeys
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
	Painter.setAtlas(self.resources.atlas)
	local w, h = love.graphics.getDimensions()
	self.ui_scale = math.min(w / TARGET_WIDTH, h / TARGET_HEIGHT)
	self.composition = ScreenComposition(self, self.inputs, self.ui_scale)
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
	self.composition:update(math.min(dt, MAX_DT))
end

function UserInterface:draw()
	self.composition:draw()
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
	self.composition:receive(event)
end

return UserInterface
