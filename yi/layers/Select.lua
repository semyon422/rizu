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
local SelectCommands = require("yi.layers.SelectCommands")
local LocationCommands = require("yi.layers.LocationCommands")

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

	self.select_commands = SelectCommands(ui.game)
	self.location_commands = LocationCommands(ui.game)
	self.next_reload_time = math.huge
end

---@param index integer
function Select:openScore(index)
	self.ui.game.scoreSelector:scrollScore(nil, index)
	self.ui.game.resultController:replayNoteChartAsync("result", self.ui.game.scoreSelector.chartplay)
	self.ui:setScreen("result")
end

function Select:enter()
	self.ui.game.chartSelector.onChanged:add(self)
	self.ui.game.chartSelector.state.onChanged:add(self)
	self.ui.game.scoreSelector.onChanged:add(self)
	local cv = self.ui.game.chartSelector.chartview
	if cv then
		self:onChartviewUpdate(cv)
		self.score_list:reload()
		self.chart_grid:reloadItems()
	end

	self.ui.command_registry:pushContext("select", self.select_commands)
	self.ui.command_registry:pushContext("locations", self.location_commands)
end

function Select:exit()
	self.ui.game.chartSelector.onChanged:remove(self)
	self.ui.game.chartSelector.state.onChanged:remove(self)
	self.ui.game.scoreSelector.onChanged:remove(self)
	self.ui.command_registry:popContext("select")
	self.ui.command_registry:popContext("locations")
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
		space = {28, 57, 64, 22, 136, 22, 562},

		Rectangle({color = Colors.panel}),
		S.Stack(),
		Rectangle({color = Colors.panel}),
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
				self.play_button
			})
		})
	})
end

function Select:createSidebar()
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
				IconButton(Resources.quads.icon_gear, nil),
				Rectangle({color = Colors.outline}):setSize(64, 2),
				IconButton(Resources.quads.icon_funnel, nil),
				IconButton(Resources.quads.icon_sparkles, nil),
				IconButton(Resources.quads.icon_keyboard, nil),
				IconButton(Resources.quads.icon_palette, nil),
			}),
		})
	})
end

---@param cv rizu.library.LocatedChartview
function Select:onChartviewUpdate(cv)
	self.background_panel:bind(cv)
end

function Select:handleKeyDown(key)
	if key == "return" then
		self.ui:setScreen("chart_loading")
	end
end

function Select:receive(event)
	Screen.receive(self, event)
	if event.type == "chartview" and event.chartview.hash then --- TODO: Why is this 'type' when it should be 'name'?
		self:onChartviewUpdate(event.chartview)
	end

	if event.type == "set_changed" then
		self.score_list:reload()
		self.chart_grid:reloadItems()
	end

	self.background_panel:receive(event)
end

return Select
