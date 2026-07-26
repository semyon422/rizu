local Screen = require("gui.Screen")
local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local Resources = require("ui.Resources")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local Colors = require("ui.Colors")
local Background = require("ui.views.Background")
local JudgeSegments = require("ui.screens.result.JudgeSegments")
local CompositeView = require("gui.CompositeView")

---@class ui.screens.result.Result : gui.Screen
---@operator call: ui.screens.result.Result
local Result = Screen + {}

---@param ui ui.UserInterface
function Result:new(ui)
	Screen.new(self)
	self.ui = ui

	self.composite = self.root:add(CompositeView()):anchorFill(0, 0, 0, 0)
	self.background = self.composite:add(Background(ui.game.backgroundModel, true))
	self.background:anchorFill(0, 0, 0, 0)
	self.background:setBrightness(0.7, true)

	self.composite:add(Image(Resources.atlas, Resources.quads.result_gradient, "fit"))
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

	self.judge_segments = self.content:add(JudgeSegments()):setAlignment(0.5, 0.5)

	self.no_score_panel = self:createNoScorePanel()

	self.root.handles_keyboard_input = true
	self.root.onKeyDown = function(_, event)
		if event.key == "escape" then
			self.ui:setScreen(self.ui.song_select, true)
		end
	end

	self.composite:setOpacity(0)
end

function Result:createNoScorePanel()
	local scale = 0.7
	local superellipse = Resources.quads.superellipse
	local _, _, iw, ih = superellipse:getViewport()
	local panel = self.content:add(View()):setSize(iw * scale, ih * scale):setAlignment(0.5, 0.5)
	panel:add(Image(Resources.atlas, Resources.quads.superellipse, nil, Colors.panel)):setScale(scale, scale)

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
	local judge_score = score_engine.judgesSource

	if not judge_score then
		self.no_score_panel:setVisible(true)
		self.no_score_panel:setOffset(0, -30)
		self.no_score_panel:moveToY(0, 0.7, "OutElastic")
		return
	else
		self.no_score_panel:setVisible(false)
	end

	self.judge_segments:bind(judge_score)
end

function Result:enter()
	self:updateInfo()
	self.composite:fadeIn(0.3, "OutQuint")
end

function Result:exit()
	Screen.exit(self)
	self.composite:fadeOut(0.3, "OutQuint")
end

return Result
