local Screen = require("gui.Screen")
local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local StackContainer = require("gui.layout.StackContainer")
local Resources = require("ui.Resources")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local Colors = require("ui.Colors")
local Background = require("ui.views.Background")
local JudgeSegments = require("ui.screens.result.JudgeSegments")
local ResultStats = require("ui.screens.result.ResultStats")
local ResultMeta = require("ui.screens.result.ResultMeta")
local CompositeView = require("gui.CompositeView")
local ChartviewFormatter = require("ui.formatters.ChartviewFormatter")
local ChartdiffFormatter = require("ui.formatters.ChartdiffFormatter")
local UiActions = require("ui.UiActions")

---@class ui.screens.result.Result : gui.Screen
---@operator call: ui.screens.result.Result
local Result = Screen + {}

---@param ui ui.UserInterface
function Result:new(ui)
	Screen.new(self)
	self.ui = ui

	self.chartview_formatter = ChartviewFormatter(
		ui.game.chartSelector.chartview,
		ui.game.persistence.configModel.configs.settings
	)

	self.chartdiff_formatter = ChartdiffFormatter(
		ui.game.computeContext.chartdiff,
		ui.game.persistence.configModel.configs.settings
	)

	self.composite = self.root:add(CompositeView()):anchorFill(0, 0, 0, 0)
	self.background = self.composite:add(Background(ui.game.backgroundModel, true))
	self.background:anchorFill(0, 0, 0, 0)
	self.background:setBrightness(0.7, true)

	self.composite:add(Image(Resources.sprites.result_gradient, "fit"))
		:fillWidth(0, 0)
		:setHeight(130)
		:setAlignmentY(1)

	self.content = self.composite:add(View()):anchorFill(20, 20, 20, 20)

	local bottom_left = self.content:add(FlowContainer({direction = "column"}))

	self.title = bottom_left:add(Label({
		font_name = "cjk_bold",
		font_size = 48,
		color = Colors.text,
		text = "Title"
	}))

	self.artist = bottom_left:add(Label({
		font_name = "cjk_bold",
		font_size = 24,
		color = Colors.accent,
		text = "Artist"
	}))

	self.chart_name = self.content:add(Label({
		font_name = "cjk_bold",
		font_size = 24,
		color = Colors.text,
		text = "Chart name"
	}))
	self.chart_name:setAlignment(1, 1)

	bottom_left:fitContent()
	bottom_left:setAlignment(0, 1)

	self.judge_segments = JudgeSegments()
	self.stats = ResultStats()
	self.meta = ResultMeta()
	self.ring = self.content:add(self:createRingPanel())
	self.no_score_panel = self.content:add(self:createNoScorePanel())

	self.composite:setOpacity(0)
end

---@param inputs gui.Inputs
function Result:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.song_select, true)
	end
end

function Result:createNoScorePanel()
	local scale = 0.7
	local superellipse = Resources.sprites.superellipse
	local iw, ih = superellipse:getDimensions()
	local panel = View():setSize(iw * scale, ih * scale):setAlignment(0.5, 0.5)
	panel:add(Image(Resources.sprites.superellipse, nil, Colors.panel)):setScale(scale, scale)

	panel:add(Label({
		font_size = 48,
		font_name = "bold",
		color = Colors.text,
		text = "No score!\n(｡•́︿•̀｡)",
		align = "center"
	})):setAlignment(0.5, 0.5)

	panel:setVisible(false)
	return panel
end

function Result:createRingPanel()
	local ring = StackContainer()

	local panel = ring:add(Image(Resources.sprites.result_info_panel, nil, Colors.panel))
		:setLayoutIgnore(true)
		:setAlignment(0, 0.5)
		:addPosition(442, 0)

	ring:add(Image(Resources.sprites.judge_segments_bg, nil, Colors.panel))
		:setAlignment(0.5, 0.5)

	ring:add(self.judge_segments):setAlignment(0.5, 0.5)
	ring:add(self.stats):setAlignment(0.5, 0.5)

	ring:fitContent()
	ring:setAlignment(0.5, 0.5)
	ring:addPosition(-378 / 2, 0) -- it's because setLayoutIgnore(true)

	panel:add(self.meta):setAlignment(0.5, 0):addPosition(0, 27)

	return ring
end

function Result:updateInfo()
	local chartview = self.ui.game.chartSelector.chartview

	if not chartview then
		self.ui:setScreen(self.ui.main_menu)
		return
	end

	self.title:setText(chartview.title)
	self.artist:setText(chartview.artist)
	self.chart_name:setText(chartview.name)

	local game = self.ui.game
	local score_engine = game.rhythm_engine.score_engine
	local judge_source = score_engine.judgesSource
	local accuracy_source = score_engine.accuracySource
	local combo_source = score_engine.comboSource ---@cast combo_source rizu.BaseScore

	if not judge_source or not accuracy_source or not combo_source then
		self.no_score_panel:setVisible(true)
		self.no_score_panel:setOffset(0, -30)
		self.no_score_panel:moveToY(0, 0.7, "OutElastic")
		self.ring:setVisible(false)
		return
	else
		self.no_score_panel:setVisible(false)
		self.ring:setVisible(true)
	end

	local timings = game.replayBase.timings
	if timings then
		self.stats:bind(accuracy_source, judge_source, combo_source, timings)
	end

	local rate = game.timeRateModel:get()
	self.chartview_formatter:setChartview(game.chartSelector.chartview)
	self.chartview_formatter:setTimeRate(rate)
	self.chartdiff_formatter:setChartdiff(game.computeContext.chartdiff)

	self.meta:bind(
		self.chartview_formatter,
		self.chartdiff_formatter
	)

	self.judge_segments:bind(judge_source)
end

function Result:enter()
	self.ui.command_registry:pushContext("result_commands", self.ui.result_commands)
	self.ui.command_registry:pushContext("ui_result_commands", self.ui.ui_result_commands)
	self:updateInfo()
	self.composite:fadeIn(0.6, "OutQuint")
end

function Result:exit()
	self.ui.command_registry:popContext("result_commands")
	self.ui.command_registry:popContext("ui_result_commands")
	Screen.exit(self)
	self.composite:fadeOut(0.3, "OutQuint")
end

return Result
