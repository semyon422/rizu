local IUserInterface = require("sphere.IUserInterface")
local Resources = require("ui.Resources")
local MainMenu = require("ui.screens.main_menu.MainMenu")
local SongSelect = require("ui.screens.song_select.SongSelect")
local ChartLoading = require("ui.screens.chart_loading.ChartLoading")
local Gameplay = require("ui.screens.gameplay.Gameplay")
local Editor = require("ui.screens.editor.Editor")
local Result = require("ui.screens.result.Result")
local LobbyList = require("ui.screens.lobby_list.LobbyList")
local Lobby = require("ui.screens.lobby.Lobby")
local MusicPlayer = require("ui.screens.music_player.MusicPlayer")
local Dlc = require("ui.screens.dlc.Dlc")
local TestScreen = require("ui.test.TestScreen")
local Inputs = require("gui.input.Inputs")
local ScreenManager = require("ui.ScreenManager")
local Overlay = require("ui.Overlay")
local Registry = require("ui.command_palette.Registry")
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
---@field editor ui.screens.editor.Editor
---@field result ui.screens.result.Result
---@field lobby_list ui.screens.lobby_list.LobbyList
---@field lobby ui.screens.lobby.Lobby
---@field music_player ui.screens.music_player.MusicPlayer
---@field dlc ui.screens.dlc.Dlc
---@field test_screen ui.test.TestScreen
---@field screen_manager ui.ScreenManager
---@field overlay ui.Overlay
---@field modal_manager ui.ModalManager
---@field command_registry ui.command_palette.Registry
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
	self.command_registry = Registry()
end

function UserInterface:load()
	Resources.load()
	self.main_menu = MainMenu(self)
	self.song_select = SongSelect(self)
	self.chart_loading = ChartLoading(self)
	self.gameplay = Gameplay(self)
	self.editor = Editor(self)
	self.result = Result(self)
	self.lobby_list = LobbyList(self)
	self.lobby = Lobby(self)
	self.music_player = MusicPlayer(self)
	self.dlc = Dlc(self)
	self.test_screen = TestScreen(self)
	self.overlay = Overlay(self)
	self.modal_manager = self.overlay.modal_manager
	self.screen_manager:registerAll({
		self.main_menu,
		self.song_select,
		self.chart_loading,
		self.gameplay,
		self.editor,
		self.result,
		self.lobby_list,
		self.lobby,
		self.music_player,
		self.dlc,
		self.test_screen,
	})
	self.screen_manager:setOverlay(self.overlay)

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
	if self.screen_manager:receive(event) then
		return
	end
	self.inputs:receive(event, default_modifiers)
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
