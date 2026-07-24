local IUserInterface = require("sphere.IUserInterface")
local Resources = require("ui.Resources")
local MainMenu = require("ui.screens.main_menu.MainMenu")
local SongSelect = require("ui.screens.song_select.SongSelect")
local ChartLoading = require("ui.screens.chart_loading.ChartLoading")
local Gameplay = require("ui.screens.gameplay.Gameplay")
local Result = require("ui.screens.result.Result")
local TestScreen = require("ui.test.TestScreen")
local Inputs = require("gui.input.Inputs")
local ScreenManager = require("ui.ScreenManager")
local Colors = require("ui.Colors")

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
---@field test_screen ui.test.TestScreen
---@field screen_manager ui.ScreenManager
---@field private prev_w number
---@field private prev_h number
---@field private inputs gui.Inputs
local UserInterface = IUserInterface + {}

---@param game sphere.GameController
---@param _directory string
function UserInterface:new(game, _directory)
	self.game = game
	self.inputs = Inputs()
	self.screen_manager = ScreenManager()
end

function UserInterface:load()
	Resources.load()
	self.main_menu = MainMenu(self)
	self.song_select = SongSelect(self)
	self.chart_loading = ChartLoading(self)
	self.gameplay = Gameplay(self)
	self.result = Result(self)
	self.test_screen = TestScreen(self)
	self.screen_manager:registerAll({
		self.main_menu,
		self.song_select,
		self.chart_loading,
		self.gameplay,
		self.result,
		self.test_screen,
	})

	local ww, wh = love.graphics.getDimensions()
	self.prev_w = ww
	self.prev_h = wh
	self:applyViewport(ww, wh)
	self:setScreen(self.main_menu)
	love.keyboard.setTextInput(true)
	love.keyboard.setKeyRepeat(true)
end

---keep_previous_visible keeps the outgoing screen active for a transition;
---call screen_manager:hide(outgoing) when its exit animation completes.
---@param screen gui.Screen
---@param keep_previous_visible boolean?
---@return boolean changed
function UserInterface:setScreen(screen, keep_previous_visible)
	return self.screen_manager:setScreen(screen, keep_previous_visible)
end

function UserInterface:unload()
	self.screen_manager:unload()
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
	self.screen_manager:acceptInputs(self.inputs)
	self.screen_manager:update(dt)
end

function UserInterface:draw()
	love.graphics.clear(Colors.background)
	self.screen_manager:draw()
end

---@param event {name: string, [integer]: any}
function UserInterface:receive(event)
	local screen = self.screen_manager.input_screen
	if event.name == "keypressed" and event[1] == "f8" then
		if screen then
			screen:printDebugLayout()
		end
		return
	end
	self.inputs:receive(event, default_modifiers)
	if screen and screen.receive then
		screen:receive(event)
	end
end

---@private
---@param w number
---@param h number
function UserInterface:applyViewport(w, h)
	local scale = h / TARGET_HEIGHT
	self.screen_manager:resize(w, h, scale)
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
