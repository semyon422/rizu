local RizuUserInterface = require("rizu.app.UserInterface")
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
local ScreenManager = require("ui.ScreenManager")
local Overlay = require("ui.Overlay")
local Registry = require("rizu.command.Registry")
local Colors = require("ui.Colors")
local LoveFilesystem = require("fs.LoveFilesystem")
local UiConfig = require("ui.UiConfig")
local UiActions = require("ui.UiActions")
local MapperatorinatorConfig = require("rizu.mapperatorinator.Config")
local MapperatorinatorWorkflow = require("rizu.mapperatorinator.Workflow")
local GlobalCommands = require("rizu.commands.GlobalCommands")
local DatabaseCommands = require("rizu.commands.DatabaseCommands")
local GameplayCommands = require("rizu.commands.GameplayCommands")
local LocationCommands = require("rizu.commands.LocationCommands")
local MultiplayerCommands = require("rizu.commands.MultiplayerCommands")
local NoteSkinCommands = require("rizu.commands.NoteSkinCommands")
local OnlineCommands = require("rizu.commands.OnlineCommands")
local PackageCommands = require("rizu.commands.PackageCommands")
local PlayConfigCommands = require("rizu.commands.PlayConfigCommands")
local ResultCommands = require("rizu.commands.ResultCommands")
local SelectCommands = require("rizu.commands.SelectCommands")
local UiGlobalCommands = require("ui.commands.UiGlobalCommands")
local UiResultCommands = require("ui.commands.UiResultCommands")
local UiSelectCommands = require("ui.commands.UiSelectCommands")

-- The tree always works in a 1080-logical-tall coordinate system; the screen
-- scales to fit the actual window height.
local TARGET_HEIGHT = 1080

---@class ui.UserInterface : rizu.app.UserInterface
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
---@field command_registry rizu.command.Registry
---@field actions gui.input.ActionMap
---@field mapperatorinator_config rizu.config.Config
---@field mapperatorinator_workflow rizu.mapperatorinator.Workflow
---@field private prev_w number
---@field private prev_h number
local UserInterface = RizuUserInterface + {}

UserInterface.name = "default_user_interface_2026"
UserInterface.display_name = "Default User Interface 2026"

---@param game sphere.GameController
---@param mount_path string
function UserInterface:new(game, mount_path)
	RizuUserInterface.new(self, game, mount_path, ScreenManager())
	self.command_registry = Registry()
	self.global_commands = GlobalCommands(game)
	self.database_commands = DatabaseCommands(game)
	self.gameplay_commands = GameplayCommands(game)
	self.location_commands = LocationCommands(game)
	self.multiplayer_commands = MultiplayerCommands(game)
	self.note_skin_commands = NoteSkinCommands(game)
	self.online_commands = OnlineCommands(game)
	self.package_commands = PackageCommands(game)
	self.play_config_commands = PlayConfigCommands(game)
	self.result_commands = ResultCommands(game)
	self.select_commands = SelectCommands(game)
	self.ui_global_commands = UiGlobalCommands(game, self)
	self.ui_result_commands = UiResultCommands(self)
	self.ui_select_commands = UiSelectCommands(game, self)
	self.config = UiConfig(LoveFilesystem(), "userdata/ui.json")
	self.config:load()
	self.mapperatorinator_config = MapperatorinatorConfig.create(LoveFilesystem())
	self.mapperatorinator_config:load()
	self.mapperatorinator_workflow = MapperatorinatorWorkflow(game, self)
	self.actions = UiActions.createMap(self.config)
	self.inputs:setActionMap(self.actions)
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

	for _, command_set in ipairs({self.global_commands, self.ui_global_commands}) do
		for _, command in ipairs(command_set) do
			self.command_registry:registerGlobal(command)
		end
	end

	local ww, wh = love.graphics.getDimensions()
	self.prev_w = ww
	self.prev_h = wh
	self:applyViewport(ww, wh)
	self:setScreen(self.main_menu)
	love.keyboard.setTextInput(true)
	love.keyboard.setKeyRepeat(true)
end

---@param dt number
function UserInterface:update(dt)
	if self:windowDimensionsChanged() then
		local ww, wh = love.graphics.getDimensions()
		self:applyViewport(ww, wh)
	end

	self.mapperatorinator_workflow:update(dt)
	RizuUserInterface.update(self, dt)
end

function UserInterface:draw()
	love.graphics.clear(Colors.background)
	RizuUserInterface.draw(self)
end

function UserInterface:unload()
	self.config:save()
	self.mapperatorinator_config:save()
	RizuUserInterface.unload(self)
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
