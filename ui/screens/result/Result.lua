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
local CompositeView = require("gui.CompositeView")
local ScoringUtils = require("ui.ScoringUtils")

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

	self.accuracy = Label({
		font_name = "outline_regular",
		font_size = 96,
		text = "97.67%",
		color = Colors.grade_s
	})

	self.grade = Label({
		font_name = "outline_regular",
		font_size = 96,
		text = "S",
		color = Colors.grade_s
	})

	self.ma_ratio = Label({
		font_name = "outline_regular",
		font_size = 96,
		text = "3:1",
		color = Colors.grade_x
	})

	self.pa_ratio = Label({
		font_name = "outline_regular",
		font_size = 96,
		text = "9:1",
		color = Colors.grade_s
	})

	self.misses = Label({
		font_name = "outline_regular",
		font_size = 96,
		text = "84x",
		color = Colors.grade_d
	})

	self.time_rate = Label({
		font_name = "outline_regular",
		font_size = 96,
		text = "1.05x",
	})

	self.difficulty = Label({
		font_name = "outline_regular",
		font_size = 96,
		text = "30.8",
	})

	self.patterns = Label({
		font_name = "regular",
		font_size = 24,
		text = "ENPS JS STAMINA",
	})

	self.score_system = Label({
		font_name = "regular",
		font_size = 24,
		text = "osu!mania V1 OD9",
		color = Colors.text_muted
	})

	self.duration = Label({
		font_name = "regular",
		font_size = 36,
		text = "7:25",
		color = Colors.text
	})

	self.ln_percent = Label({
		font_name = "regular",
		font_size = 36,
		text = "0%",
		color = Colors.text
	})

	self.tempo = Label({
		font_name = "regular",
		font_size = 36,
		text = "252",
		color = Colors.text
	})

	self.ring = self.content:add(self:createRingPanel())
	self.no_score_panel = self.content:add(self:createNoScorePanel())

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
		:setAlignment(1, 0.5)
		:addPosition(378, 0)
		:setOpacity(0.9)

	ring:add(Image(Resources.sprites.result_info_panel_stroke, nil, Colors.outline))
		:setLayoutIgnore(true)
		:setAlignment(1, 0.5)
		:addPosition(378, 0)

	ring:add(Image(Resources.sprites.judge_segments_ring, nil, Colors.outline))
		:setAlignment(0.5, 0.5)
	ring:add(Image(Resources.sprites.judge_segments_bg, nil, Colors.panel))
		:setAlignment(0.5, 0.5)
		:setOpacity(0.9)

	ring:add(self.judge_segments):setAlignment(0.5, 0.5)

	ring:fitContent()
	ring:setAlignment(0.5, 0.5)
	ring:addPosition(-378 / 2, 0) -- it's because setLayoutIgnore(true)

	local row = panel:add(FlowContainer({direction = "row", gap = 30, align = 0.5}))

	local dura_cell = row:add(FlowContainer({direction = "column", align = 0.5, gap = 4}))
	dura_cell:add(Image(Resources.sprites.icon_clock, nil, Colors.text_muted))
	dura_cell:add(self.duration)
	dura_cell:fitContent()

	local ln_cell = row:add(FlowContainer({direction = "column", align = 0.5, gap = 4}))
	ln_cell:add(Label({
		font_name = "regular",
		font_size = 24,
		text = "LN",
		color = Colors.text_muted
	}))
	ln_cell:add(self.ln_percent)
	ln_cell:setOffset(0, -2) -- Text is a bit larger than icons
	ln_cell:fitContent()

	local tempo_cell = row:add(FlowContainer({direction = "column", align = 0.5, gap = 4}))
	tempo_cell:add(Image(Resources.sprites.icon_metronome, nil, Colors.text_muted))
	tempo_cell:add(self.tempo)
	tempo_cell:fitContent()

	row:fitContent():setAlignment(0.5, 0):addPosition(0, 27)

	panel:add(self.time_rate):addPosition(125, 133):setScale(36 / 96, 36 / 96)
	panel:add(self.difficulty):addPosition(229, 117):setScale(64 / 96, 64 / 96)
	panel:add(self.patterns)
		:setAlignment(0.5, 0)
		:addPosition(0, 201)

	panel:add(self.score_system)
		:setAlignment(0.5, 0)
		:addPosition(0, 248)

	ring:add(self.accuracy):setAlignment(0.5, 0.5)
	ring:add(self.grade)
		:setAlignment(0.5, 0.5):setScale(64 / 96, 64 / 96):setOffset(0, -90)

	local numbers = ring:add(FlowContainer({
		direction = "row",
		gap = 50,
	}))

	numbers:add(self.ma_ratio)
	numbers:add(self.pa_ratio)
	numbers:add(self.misses)

	numbers:fitContent()
	numbers:setAlignment(0.5, 0.5)
	numbers:setOffset(0, 90)
	numbers:setPivot(0.5, 0.5)
	numbers:setScale(48 / 96, 48 / 96) -- Have to scale here because we have stupid fixed size fonts

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

	self.accuracy:setText(accuracy_source:getAccuracyString())

	local timings = game.replayBase.timings

	if timings then
		local grade = ScoringUtils.getGrade(timings.name, accuracy_source:getAccuracy()) or "F"
		local color = ScoringUtils.getGradeColor(timings.name, grade)
		self.grade:setText(grade)
		self.grade.color = color -- TODO: Label:setColor()
		self.accuracy.color = color
	else
		error("TODO: auto timings")
		-- They should be stored either in chartview or in chartmeta or in chartdiff
	end

	local judges = judge_source:getJudges()
	local j1 = judges[1]
	local j2 = judges[2]

	local marv_perf = j1 + j2
	local other = 0
	for _, v in ipairs(judges) do
		other = other + v
	end
	other = other - marv_perf

	if j1 > j2 then
		self.ma_ratio:setText(("%i:1"):format(j1 / j2))
	else
		self.ma_ratio:setText(("1:%i"):format(j2 / j1))
	end

	if marv_perf > other then
		self.pa_ratio:setText(("%i:1"):format(marv_perf / other))
	else
		self.pa_ratio:setText(("1:%i"):format(other / marv_perf))
	end

	self.misses:setText(("%ix"):format(combo_source.missCount))

	self.judge_segments:bind(judge_source)
end

function Result:enter()
	self:updateInfo()
	self.composite:fadeIn(0.6, "OutQuint")
end

function Result:exit()
	Screen.exit(self)
	self.composite:fadeOut(0.3, "OutQuint")
end

return Result
