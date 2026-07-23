local IUserInterface = require("sphere.IUserInterface")
local Resources = require("ui.Resources")
local TestScreen = require("ui.test.TestScreen")
local Inputs = require("gui.input.Inputs")

-- The tree always works in a 1080-logical-tall coordinate system; the screen
-- scales to fit the actual window height.
local TARGET_HEIGHT = 1080

---@class ui.UserInterface : sphere.IUserInterface
---@operator call: ui.UserInterface
---@field private screen ui.test.TestScreen
---@field private prev_w number
---@field private prev_h number
---@field private inputs gui.Inputs
local UserInterface = IUserInterface + {}

---@param game sphere.GameController
---@param _directory string
function UserInterface:new(game, _directory)
	self.game = game
	self.screen = TestScreen()
	self.inputs = Inputs()
end

function UserInterface:load()
	local ww, wh = love.graphics.getDimensions()
	self.prev_w = ww
	self.prev_h = wh
	self:applyViewport(ww, wh)
	self.screen:load()
	love.keyboard.setTextInput(true)
	love.keyboard.setKeyRepeat(true)
end

function UserInterface:unload()
	self.screen:unload()
end

---@type gui.ModifierKeys
local default_modifiers = {control = false, shift = false, alt = false, super = false}

---@param dt number
function UserInterface:update(dt)
	if self:windowDimensionsChanged() then
		local ww, wh = love.graphics.getDimensions()
		self:applyViewport(ww, wh)
	end

	local mouse_x, mouse_y = love.mouse.getPosition()
	self.inputs:beginFrame(mouse_x, mouse_y)
	self.screen:acceptInputs(self.inputs)
	self.screen:update(dt)
end

function UserInterface:draw()
	self.screen:draw()
end

---@param event {name: string, [integer]: any}
function UserInterface:receive(event)
	if event.name == "keypressed" then
		self.screen:receive(event)
	end

	self.inputs:receive(event, default_modifiers)
end

---@private
---@param w number
---@param h number
function UserInterface:applyViewport(w, h)
	local scale = h / TARGET_HEIGHT
	self.screen:setUIScale(h / TARGET_HEIGHT)
	self.screen:resize(w, h)
	Resources.setUIScale(scale)
	Resources.setFontScale(1)
end

---@private
---@return boolean
function UserInterface:windowDimensionsChanged()
	local ww, wh = love.graphics.getDimensions()
	local pw, ph = self.prev_w, self.prev_h
	self.prev_w = ww
	self.prev_h = wh
	return ww ~= pw or wh ~= ph
end

return UserInterface
