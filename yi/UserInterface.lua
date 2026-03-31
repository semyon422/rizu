local IUserInterface = require("sphere.IUserInterface")
local Context = require("yi.Context")
local Inputs = require("ui.input.Inputs")
local Resources = require("yi.Resources")
local Painter = require("yi.Painter")

local Background = require("yi.layers.Background")
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
	self.ctx = Context(self.game, self.inputs, self.resources)
end

function UserInterface:load()
	self.resources:load()
	Painter.setAtlas(self.resources.atlas)
	Painter.setScale(1)

	self.background = Background(self.ctx)
	self.config = Config(self.ctx)

	self.layers = {
		--self.background,
		self.config,
	}

	self.ctx:setLayers(self.background)
end

---@param dt number
function UserInterface:update(dt)
	dt = math.min(dt, MAX_DT)

	if self:dimensionsChanged() then
		local w, h = love.graphics.getDimensions()
		local layout_scale = math.min(h / TARGET_HEIGHT, w / TARGET_WIDTH)
		local ui_scale = layout_scale
		Painter.setScale(ui_scale)
		for _, v in ipairs(self.layers) do
			v:updateDimensions(w, h, layout_scale, ui_scale)
		end
	end

	self.modifiers.control = love.keyboard.isDown("lctrl", "rctrl")
	self.modifiers.alt = love.keyboard.isDown("lalt", "ralt")
	self.modifiers.shift = love.keyboard.isDown("lshift", "rshift")

	self.inputs:beginFrame(love.mouse.getPosition())

	for _, v in ipairs(self.layers) do
		v:update(dt)
	end

	for i = #self.layers, 1, -1 do
		self.layers[i]:acceptInputs(self.inputs)
	end
end

function UserInterface:draw()
	for _, v in ipairs(self.layers) do
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
end

return UserInterface
