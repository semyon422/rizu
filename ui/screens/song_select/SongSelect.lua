local Screen = require("gui.Screen")
local View = require("gui.View")
local Flex = require("gui.layout.Flex")
local Flow = require("gui.layout.Flow")
local Stack = require("gui.layout.Stack")
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
	self.root.arrange_strategy = Flex({direction = "row", sizes = {"*", SIDEBAR_LINE_WIDTH, SIDEBAR_WIDTH}})
	self:createContent()
	self.sidebar_line = self.root:add(Rectangle(Colors.outline))
	self:createSidebar()

	self.root:setOpacity(0)
	self.root:fadeIn(0.4, "OutCubic")
end

function SongSelect:createContent()
	self.content = self.root:add(View())
	self.content.arrange_strategy = Flex({direction = "column", sizes = {70, 2, "*", 2, 70}})
	self.content:add(self:createHeader())
	self.content:add(Rectangle(Colors.outline)).align_self = "fill"

	local body = self.content:add(View())
	body.arrange_strategy = Flex({direction = "row", padding = {0, 20, 0, 20}, sizes = {"*", "44%", "*", "46%", "*"}})
	body:add(View())
	body:add(self:createLeftColumn())
	body:add(View())
	body:add(self:createRightColumn())
	body:add(View())

	self.content:add(Rectangle(Colors.outline)).align_self = "fill"
	self.content:add(self:createFooter())
end

function SongSelect:createLeftColumn()
	local column = View()
	column.arrange_strategy = Flex({direction = "column", sizes = {469, "*", 400}})
	column:add(BackgroundPanel(self.ui.game.backgroundModel, self.ui.game))
	column:add(View())
	self.score_list = column:add(ScoreList(self.ui.game.scoreSelector, function() end))
	return column
end

function SongSelect:createRightColumn()
	local column = View()
	column.arrange_strategy = Flex({direction = "column", sizes = {40, "*", 122, "*", 136, "*", 562}})
	local heading = View()
	heading.arrange_strategy = Flex({direction = "row", padding = {10, 0, 0, 10}, sizes = {"*", "*"}})
	heading:add(Label({
		font_name = "regular",
		font_size = 24,
		text = "Displaying the entire library",
		color = Colors.text_muted,
	}))
	heading:add(Label({
		font_name = "regular",
		font_size = 24,
		text = "No filters",
		color = Colors.text_muted,
		align = "right",
	}))
	column:add(heading)
	column:add(View())
	column:add(InfoPanel())
	column:add(View())
	self.chart_grid = column:add(ChartGrid(self.ui.game.chartSelector))
	column:add(View())
	self.chart_sets = column:add(ChartSets(self.ui.game.chartSelector, function() end))
	return column
end

function SongSelect:createHeader()
	local header = View()
	header.arrange_strategy = Stack()
	header:add(Rectangle(Colors.panel))

	local row = header:add(View())
	row.arrange_strategy = Flex({
		sizes = {"*", "44%", "*", "46%", "*"},
		direction = "row",
		align = "center",
	})

	row:add(View())

	local left = row:add(View())
	left.arrange_strategy = Flow({
		direction = "row",
		gap = 32,
		align = 0.5
	})
	left:add(Image(Resources.atlas, Resources.quads.rizu_small))
	left:add(Label({
		font_name = "regular",
		font_size = 24,
		text = "Online: 1",
	}))
	row:add(View())

	row:add(View())

	row:add(View())
	return header
end

function SongSelect:createFooter()
	local back_button = FooterButton(Colors.back_button, {1, 1, 1, 1}, "BACK", function() end)

	local play_button = FooterButton(Colors.play_button, {0, 0, 0, 1}, "PLAY", function()
		if self.ui.game.chartSelector:chartExists() then
			self.ui:setScreen(self.ui.chart_loading)
		end
	end)
	local time_rate = TimeRate(self.ui.game.timeRateModel, self.ui.game.modifierSelectModel)
	local gameplay_modifiers = GameplayModifiers()

	local footer = View()
	footer.arrange_strategy = Stack()
	footer:add(Rectangle(Colors.panel))

	-- Left
	local left = footer:add(View())
	left.arrange_strategy = Flow({
		direction = "row",
		gap = 10
	})
	left:add(back_button)

	-- Right
	local right = footer:add(View())
	right.arrange_strategy = Flex({
		direction = "row",
		sizes = {"content", "content", "content"},
		gap = 10,
		justify = "end",
		align_items = "center",
	})
	right:add(gameplay_modifiers)
	right:add(time_rate)
	right:add(play_button)

	return footer
end

function SongSelect:createSidebar()
	self.sidebar = self.root:add(View())
	self.sidebar.arrange_strategy = Stack()
	self.sidebar:add(Rectangle(Colors.panel))

	local buttons = self.sidebar:add(View())
	buttons.arrange_strategy = Flow({
		direction = "column",
		gap = 10,
		align = 0.5,
		padding = {0, 10, 0, 0}
	})

	buttons:addArray({
		buttons:add(IconButton(Resources.quads.icon_folder)),
		buttons:add(IconButton(Resources.quads.icon_download)),
		buttons:add(Rectangle(Colors.outline)):setSize(48, 2),
		buttons:add(IconButton(Resources.quads.icon_gear)),
		buttons:add(IconButton(Resources.quads.icon_sparkles, function() end)),
		buttons:add(IconButton(Resources.quads.icon_funnel, function() end)),
		buttons:add(IconButton(Resources.quads.icon_keyboard, function() end)),
		buttons:add(IconButton(Resources.quads.icon_palette, function() end))
	})
end

return SongSelect
