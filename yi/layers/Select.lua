local Screen = require("gui.Screen")
local S = require("gui.composition.Strategies")
local Colors = require("yi.Colors")
local Resources = require("yi.Resources")
local Rectangle = require("yi.views.Rectangle")
local Image = require("yi.views.Image")
local Label = require("yi.views.Label")
local BackgroundPanel = require("yi.views.select.BackgroundPanel")
local ScoreList = require("yi.views.select.ScoreList")
local ChartSets = require("yi.views.select.ChartSets")
local ChartGrid = require("yi.views.select.ChartGrid")
local PlayerInfo = require("yi.views.PlayerInfo")
local SessionInfo = require("yi.views.SessionInfo")
local FooterButton = require("yi.views.FooterButton")
local IconButton = require("yi.views.IconButton")
local TimeRate = require("yi.views.select.TimeRate")
local GameplayModifiers = require("yi.views.select.GameplayModifiers")
local InfoPanel = require("yi.views.select.InfoPanel")
local SelectCommands = require("yi.layers.SelectCommands")
local LocationCommands = require("yi.layers.LocationCommands")
local PlayConfigCommands = require("yi.layers.PlayConfigCommands")
local NoteSkinCommands = require("yi.layers.NoteSkinCommands")
local PackageCommands = require("yi.layers.PackageCommands")
local OnlineCommands = require("yi.layers.OnlineCommands")
local DatabaseCommands = require("yi.layers.DatabaseCommands")
local MultiplayerCommands = require("yi.layers.MultiplayerCommands")

---@class yi.layers.Select: gui.Screen
---@operator call: yi.layers.Select
local Select = Screen + {}

local HORIZONTAL_PARTITION = {"*", -0.44, "*", -0.46, "*"}

---@param ui yi.UserInterface
function Select:new(ui)
	Screen.new(self)
	self.ui = ui
	self.background_panel = BackgroundPanel(ui.game.backgroundModel, ui.game)
	self.score_list = ScoreList(ui.game.scoreSelector, function(i) self:openScore(i) end)
	self.chart_sets = ChartSets(ui.game.chartSelector, function(i) end)
	self.chart_grid = ChartGrid(ui.game.chartSelector)
	self.player_info = PlayerInfo("Username", 1, 20.00, 95.05)
	self.session_info = SessionInfo():setPosition(10, 2)
	self.time_rate = TimeRate(ui.game.timeRateModel, ui.game.modifierSelectModel)
	self.gameplay_modifiers = GameplayModifiers()
	self.info_panel = InfoPanel()

	self.location_label = Label({
		font_name = "regular",
		font_size = 24,
		text = "Displaying the entire library",
		color = Colors.text_muted
	}):setPivot(0, 0.5)

	self.filters_label = Label({
		font_name = "regular",
		font_size = 24,
		text = "No filters",
		color = Colors.text_muted
	}):setPivot(1, 0.5)

	self.back_button = FooterButton(Colors.back_button, {1, 1, 1, 1}, "QUIT", function()
		love.event.quit()
	end)
	self.play_button = FooterButton(Colors.play_button, {0, 0, 0, 1}, "PLAY", function()
		self.ui:setScreen("chart_loading")
	end)

	self.root = S.Stack({
		S.Track({
			space = {"*", 2, 64},
			direction = "row",

			S.Track({
				direction = "column",
				space = {70, 2, "*", 2, 70},

				self:createHeader(),
				Rectangle({color = Colors.outline}),
				S.Stack({
					padding = {0, 20, 20, 0},
					S.Track({
						direction = "row",
						space = HORIZONTAL_PARTITION,
						S.Stack(), -- Left gap
						self:createLeftColumn(),
						S.Stack(), -- Center gap
						self:createRightColumn(),
						S.Stack(), -- Right gap
					}),
				}),
				Rectangle({color = Colors.outline}),
				self:createFooter()
			}),
			Rectangle({color = Colors.outline}), -- Line
			self:createSidebar()
		}),
	})

	self.select_commands = SelectCommands(ui.game, ui)
	self.location_commands = LocationCommands(ui.game)
	self.play_config_commands = PlayConfigCommands(ui.game)
	self.noteskin_commands = NoteSkinCommands(ui.game)
	self.package_commands = PackageCommands(ui.game)
	self.online_commands = OnlineCommands(ui.game)
	self.database_commands = DatabaseCommands(ui.game)
	self.multiplayer_commands = MultiplayerCommands(ui.game)
	self.next_reload_time = math.huge
end

---@param index integer
function Select:openScore(index)
	self.ui.game.scoreSelector:scrollScore(nil, index)
	self.ui.game.resultController:replayNoteChartAsync("result", self.ui.game.scoreSelector.chartplay)
	self.ui:setScreen("result")
end

function Select:enter()
	self.ui.game.chartSelector:notifyChartviewChanged()

	self.ui.game.chartSelector:onChanged(self)
	self.ui.game.chartSelector.state:onChanged(self)
	self.ui.game.chartSelector.stores[2]:onChanged(self)
	self.ui.game.scoreSelector:onChanged(self)
	local cv = self.ui.game.chartSelector.chartview
	if cv then
		self:onChartviewUpdate(cv)
		self:updateInfo()
	end

	self.ui.command_registry:pushContext("select", self.select_commands)
	self.ui.command_registry:pushContext("locations", self.location_commands)
	self.ui.command_registry:pushContext("play_config", self.play_config_commands)
	self.ui.command_registry:pushContext("noteskins", self.noteskin_commands)
	self.ui.command_registry:pushContext("packages", self.package_commands)
	self.ui.command_registry:pushContext("online", self.online_commands)
	self.ui.command_registry:pushContext("database", self.database_commands)
	self.ui.command_registry:pushContext("multiplayer", self.multiplayer_commands)
end

function Select:exit()
	self.ui.game.chartSelector:offChanged(self)
	self.ui.game.chartSelector.state:offChanged(self)
	self.ui.game.chartSelector.stores[2]:offChanged(self)
	self.ui.game.scoreSelector:offChanged(self)
	self.ui.command_registry:popContext("select")
	self.ui.command_registry:popContext("locations")
	self.ui.command_registry:popContext("play_config")
	self.ui.command_registry:popContext("noteskins")
	self.ui.command_registry:popContext("packages")
	self.ui.command_registry:popContext("online")
	self.ui.command_registry:popContext("database")
	self.ui.command_registry:popContext("multiplayer")
end

function Select:createLeftColumn()
	return S.Track({
		direction = "column",
		space = {469, "*", 400},
		self.background_panel,
		S.Stack(),
		self.score_list
	})
end

function Select:createRightColumn()
	return S.Track({
		direction = "column",
		space = {40, "*", 122, "*", 136, "*", 562},

		S.Stack({
			Rectangle({color = Colors.panel}),
			S.Stack({
				padding = {10, 0, 0, 10},
				self.location_label,
				self.filters_label
			})
		}),
		S.Stack(),
		self.info_panel,
		S.Stack(),
		self.chart_grid,
		S.Stack(),
		self.chart_sets
	})
end

function Select:createHeader()
	return S.Stack({
		Rectangle({color = Colors.panel}),
		S.Track({
			direction = "row",
			space = HORIZONTAL_PARTITION,

			S.Stack(),
			S.Anchor({
				pivot = {0, 0.5},

				S.Flow({
					direction = "row",
					align = 0.5,
					gap = 32,
					Image({quad = Resources.quads.rizu_small}),
					Label({font_name = "regular", font_size = 24, text = "Online: 1"})
				})
			}),
			S.Stack(),
			S.Stack(),
			S.Stack(),
		})
	})
end

function Select:createFooter()
	return S.Stack({
		Rectangle({color = Colors.panel}),
		S.Anchor({
			pivot = {0, 0.5},

			S.Flow({
				direction = "row",
				gap = 10,
				align = 0.5,
				self.back_button,
				self.player_info,
				self.session_info
			})
		}),
		S.Anchor({
			pivot = {1, 0.5},

			S.Flow({
				direction = "row",
				gap = 10,
				align = 0.5,
				self.gameplay_modifiers,
				self.time_rate,
				self.play_button
			})
		})
	})
end

function Select:createSidebar()
	local button_config = function()
		--self.ui:setScreen("config")
	end

	local button_modifiers = function()
		self.ui.modals:open("modifiers")
	end

	local button_input = function()
		self.ui.modals:open("input")
	end

	local button_filters = function()
		self.ui.modals:open("filters")
	end

	local button_noteskins = function()
		self.ui.modals:open("noteskins")
	end

	return S.Stack({
		Rectangle({color = Colors.panel}),

		S.Stack({
			padding = {0, 10, 10, 0},
			S.Track({
				direction = "column",
				gap = 10,
				align = 0.5,
				IconButton(Resources.quads.icon_folder),
				IconButton(Resources.quads.icon_download),
				IconButton(Resources.quads.icon_gear, button_config),
				Rectangle({color = Colors.outline}):setSize(64, 2),
				IconButton(Resources.quads.icon_sparkles, button_modifiers),
				IconButton(Resources.quads.icon_funnel, button_filters),
				IconButton(Resources.quads.icon_keyboard, button_input),
				IconButton(Resources.quads.icon_palette, button_noteskins),
			}),
		})
	})
end

---@param cv rizu.library.LocatedChartview
function Select:onChartviewUpdate(cv)
	self.background_panel:bind(cv)
	self.info_panel:bind(cv)
end

function Select:updateInfo()
	self.score_list:reload()
	self.chart_grid:reloadItems()
	self.gameplay_modifiers:bind(self.ui.game.replayBase)
end

function Select:handleKeyDown(key)
	if key == "return" then
		self.ui:setScreen("chart_loading")
	end
end

function Select:receive(event)
	Screen.receive(self, event)
	if event.type == "chartview_changed" and event.chartview and event.chartview.hash then
		self:onChartviewUpdate(event.chartview)
	end

	if event.type == "selected_set_changed" then
		self:updateInfo()
	elseif event.type == "score_items_changed" then
		self.score_list:reload()
	elseif event.type == "list_count_changed" or event.type == "list_item_loaded" then
		self.chart_grid:requestReloadItems()
	end

	self.background_panel:receive(event)
end

return Select
