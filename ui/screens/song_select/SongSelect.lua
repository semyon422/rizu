local Screen = require("gui.Screen")
local View = require("gui.View")
local TrackContainer = require("gui.layout.TrackContainer")
local FlowContainer = require("gui.layout.FlowContainer")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local BackgroundPanel = require("ui.screens.song_select.BackgroundPanel")
local ScoreList = require("ui.screens.song_select.ScoreList")
local ChartSets = require("ui.screens.song_select.ChartSets")
local ChartGrid = require("ui.screens.song_select.ChartGrid")
local InfoPanel = require("ui.screens.song_select.InfoPanel")
local GameplayModifiers = require("ui.screens.song_select.GameplayModifiers")
local TimeRate = require("ui.screens.song_select.TimeRate")
local FooterButton = require("ui.screens.song_select.FooterButton")
local Image = require("ui.views.Image")
local IconButton = require("ui.views.IconButton")
local Label = require("ui.views.Label")
local Rectangle = require("ui.views.Rectangle")

---@class ui.screens.song_select.SongSelect : gui.Screen
---@operator call: ui.screens.song_select.SongSelect
local SongSelect = Screen + {}

local SIDEBAR_LINE_WIDTH = 2
local SIDEBAR_WIDTH = 64

---@param ui ui.UserInterface
function SongSelect:new(ui)
	Screen.new(self)
	self.ui = ui

	self.background_panel = BackgroundPanel(self.ui.game.backgroundModel, self.ui.game)
	self.score_list = ScoreList(self.ui.game.scoreSelector, function() end)
	self.chart_grid = ChartGrid(self.ui.game.chartSelector)
	self.chart_sets = ChartSets(self.ui.game.chartSelector, function() end)

	self.back_button = FooterButton(Colors.back_button, {1, 1, 1, 1}, "BACK", function()
		self.ui:setScreen(self.ui.main_menu, true)
	end)

	self.play_button = FooterButton(Colors.play_button, {0, 0, 0, 1}, "PLAY", function()
		if self.ui.game.chartSelector:chartExists() then
			self.ui:setScreen(self.ui.chart_loading, true)
		end
	end)

	self.time_rate = TimeRate(self.ui.game.timeRateModel, self.ui.game.modifierSelectModel)
	self.gameplay_modifiers = GameplayModifiers()

	self.root = TrackContainer({direction = "row"})
	self:createContent()
	self.root:add(Rectangle(Colors.outline), 2)
	self:createSidebar()

	self.root:setOpacity(0)
end

function SongSelect:enter()
	self.root:fadeIn(0.3, "OutCubic")
end

function SongSelect:exit()
	Screen.exit(self)
	self.root:fadeOut(0.2, "InCubic")
	return true
end

function SongSelect:createContent()
	self.content = self.root:add(TrackContainer({
		direction = "column"
	}), "*")
	self.content:add(self:createHeader(), 70)
	self.content:add(Rectangle(Colors.outline), 2)

	local body = self.content:add(TrackContainer({
		direction = "row",
		padding = {0, 20, 0, 20}
	}), "*")

	body:add(View(), "*")
	body:add(self:createLeftColumn(), "44%")
	body:add(View(), "*")
	body:add(self:createRightColumn(), "46%")
	body:add(View(), "*")

	self.content:add(self:createFooter(), 70)
end

function SongSelect:createLeftColumn()
	local column = TrackContainer({
		direction = "column"
	})
	column:add(self.background_panel, 469)
	column:add(View())
	column:add(self.score_list, 400)
	return column
end

function SongSelect:createRightColumn()
	local column = TrackContainer({
		direction = "column"
	})

	local heading = View()

	heading:add(Label({
		font_name = "regular",
		font_size = 24,
		text = "Displaying the entire library",
		color = Colors.text_muted,
	})):setAlignment(0, 0.5)

	heading:add(Label({
		font_name = "regular",
		font_size = 24,
		text = "No filters",
		color = Colors.text_muted,
		align = "right",
	})):setAlignment(1, 0.5)

	column:add(heading, 40)
	column:add(View(), "*")
	column:add(InfoPanel(), 122)
	column:add(View(), "*")
	column:add(self.chart_grid, 136)
	column:add(View(), "*")
	column:add(self.chart_sets, 562)
	return column
end

function SongSelect:createHeader()
	local header = View()
	header:add(Rectangle(Colors.panel)):anchorFill(0, 0, 0, 0)

	local row = header:add(TrackContainer({
		direction = "row",
	}))
	row:anchorFill(0, 0, 0, 0)

	row:add(View(), "*")

	local left = row:add(FlowContainer({
		direction = "row",
		gap = 32,
		align = 0.5
	}), "44%")

	left:add(Image(Resources.atlas, Resources.quads.rizu_small))
	left:add(Label({
		font_name = "regular",
		font_size = 24,
		text = "Online: 1",
	}))

	row:add(View(), "*")
	row:add(View(), "46%")
	row:add(View(), "*")
	return header
end

function SongSelect:createFooter()
	local footer = View()
	footer:add(Rectangle(Colors.panel):anchorFill(0, 0, 0, 0))

	local left = footer:add(FlowContainer({
		direction = "row",
		gap = 10,
		align = 0.5
	}))
	left:add(self.back_button)
	left:fitContent()
	left:setAlignment(0, 0.5)

	local right = footer:add(FlowContainer({
		direction = "row",
		gap = 10,
		align = 0.5
	}))
	right:add(self.gameplay_modifiers)
	right:add(self.time_rate)
	right:add(self.play_button)
	right:fitContent()
	right:setAlignment(1, 0.5)

	return footer
end

function SongSelect:createSidebar()
	self.sidebar = self.root:add(View(), 64)
	self.sidebar:add(Rectangle(Colors.panel)):anchorFill(0, 0, 0, 0)

	local buttons = self.sidebar:add(FlowContainer({
		direction = "column",
		gap = 10,
		align = 0.5,
		padding = {0, 10, 0, 0}
	})):anchorFill(0, 0, 0, 0)

	buttons:addArray({
		IconButton(Resources.quads.icon_folder),
		IconButton(Resources.quads.icon_download),
		Rectangle(Colors.outline):setSize(48, 2),
		IconButton(Resources.quads.icon_gear),
		IconButton(Resources.quads.icon_sparkles, function() end),
		IconButton(Resources.quads.icon_funnel, function() end),
		IconButton(Resources.quads.icon_keyboard, function() end),
		IconButton(Resources.quads.icon_palette, function() end)
	})
end

return SongSelect
