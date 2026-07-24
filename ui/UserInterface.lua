local IUserInterface = require("sphere.IUserInterface")
local Resources = require("ui.Resources")
local MainMenu = require("ui.screens.main_menu.MainMenu")
local SongSelect = require("ui.screens.song_select.SongSelect")
local ChartLoading = require("ui.screens.chart_loading.ChartLoading")
local Gameplay = require("ui.screens.gameplay.Gameplay")
local Result = require("ui.screens.result.Result")
local Inputs = require("gui.input.Inputs")

-- The tree always works in a 1080-logical-tall coordinate system; the screen
-- scales to fit the actual window height.
local TARGET_HEIGHT = 1080

---@class ui.UserInterface : sphere.IUserInterface
---@operator call: ui.UserInterface
---@field main_menu ui.screens.main_menu.MainMenu
---@field song_select ui.screens.song_select.SongSelect
---@field chart_loading ui.screens.chart_loading.ChartLoading
---@field gameplay ui.screens.gameplay.Gameplay
---@field result ui.screens.result.Result
---@field private screen gui.Screen
---@field private prev_w number
---@field private prev_h number
---@field private inputs gui.Inputs
local UserInterface = IUserInterface + {}

---@param game sphere.GameController
---@param _directory string
function UserInterface:new(game, _directory)
	self.game = game
	self.inputs = Inputs()
end

function UserInterface:load()
	Resources.load()
	self.main_menu = MainMenu(self)
	self.song_select = SongSelect(self)
	self.chart_loading = ChartLoading(self)
	self.gameplay = Gameplay(self)
	self.result = Result(self)
	self:setScreen(self.main_menu)

	local ww, wh = love.graphics.getDimensions()
	self.prev_w = ww
	self.prev_h = wh
	self:applyViewport(ww, wh)
	love.keyboard.setTextInput(true)
	love.keyboard.setKeyRepeat(true)
end

---@param screen gui.Screen
function UserInterface:setScreen(screen)
	if self.screen and self.screen.exit then
		self.screen:exit()
	end

	self.screen = screen
	if not self.screen.loaded then
		self.screen:load()
		self:applyViewport(love.graphics.getDimensions())
	end

	if self.screen.enter then
		self.screen:enter()
	end
end

function UserInterface:unload()
	if self.screen.exit then
		self.screen:exit()
	end
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
	if event.name == "keypressed" and event[1] == "f8" then
		self.screen:printDebugLayout()
		return
	end
	self.inputs:receive(event, default_modifiers)
	if self.screen.receive then
		self.screen:receive(event)
	end
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
