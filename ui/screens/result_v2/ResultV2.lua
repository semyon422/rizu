local Screen = require("gui.Screen")
local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local ShadowCompositeView = require("gui.ShadowCompositeView")
local CompositeView = require("gui.CompositeView")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local Button = require("ui.views.Button")
local Background = require("ui.views.Background")
local BgaPreview = require("ui.views.BgaPreview")
local ChartviewFormatter = require("ui.formatters.ChartviewFormatter")
local ResultJudges = require("ui.screens.result_v2.ResultJudges")
local ResultDifficulty = require("ui.screens.result_v2.ResultDifficulty")
local ChartdiffFormatter = require("ui.formatters.ChartdiffFormatter")
local ValueCells = require("ui.screens.result_v2.ValueCells")
local ResultStatus = require("ui.screens.result_v2.ResultStatus")
local ResultMutators = require("ui.screens.result_v2.ResultMutators")
local ResultAccuracy = require("ui.screens.result_v2.ResultAccuracy")
local ScoreSystemFormatter = require("ui.formatters.ScoreSystemFormatter")
local UiActions = require("ui.UiActions")

-- Layout follows result_design/index.html (1920x1080 logical).
local EDGE = 72
local TITLE_TOP = 44
local TITLE_LINE_HEIGHT = 75 -- 68px * 1.1
local STATUS_TOP = 62
local CONTENT_TOP = 196
local COLUMN_RIGHT_WIDTH = 718
local FOOTER_BOTTOM = 40
local BUTTON_HEIGHT = 56
local BUTTON_GAP = 12

---@class ui.screens.result_v2.ResultV2 : gui.Screen
---@operator call: ui.screens.result_v2.ResultV2
local ResultV2 = Screen + {}

---@param ui ui.UserInterface
function ResultV2:new(ui)
	Screen.new(self)
	self.ui = ui

	self.chartview_formatter = ChartviewFormatter(
		ui.game.chartSelector.chartview,
		ui.game.settings
	)

	self.chartdiff_formatter = ChartdiffFormatter(
		ui.game.computeContext.chartdiff,
		ui.game.settings
	)

	self.composite = self.root:add(CompositeView()):anchorFill(0, 0, 0, 0)

	-- Sharp fullscreen chart art; legibility comes from the scrims below, not from dimming it.
	self.background = self.composite:add(Background(ui.game.backgroundModel, true))
	self.background:anchorFill(0, 0, 0, 0)
	self.bga_preview = self.composite:add(BgaPreview(ui.game.previewModel)):anchorFill(0, 0, 0, 0)

	self.composite:add(Image(Resources.sprites.result_v2_scrim_horizontal, "fit")):anchorFill(0, 0, 0, 0)
	self.composite:add(Image(Resources.sprites.result_v2_scrim_vertical, "fit")):anchorFill(0, 0, 0, 0)

	-- Everything above the background casts a soft shadow, sprites included.
	self.content = self.composite:add(ShadowCompositeView({blur = 6, offset_y = 3, opacity = 0.85}))
	self.content:anchorFill(0, 0, 0, 0)

	self:createName()
	self.status = self.content:add(ResultStatus())
	self.status:setAlignment(1, 0):addPosition(-EDGE, STATUS_TOP)
	self:createAccuracy()
	self:createFooter()

	self.composite:setOpacity(0)
end

---@private
function ResultV2:createName()
	local name = self.content:add(FlowContainer({direction = "column", gap = 4}))

	-- The font's own line box is much taller than the 1.1 line height of the design, which pushed
	-- the artist row down. The title gets a fixed box and its label is centered in it.
	self.title_box = name:add(View())
	self.title_box:setSize(0, TITLE_LINE_HEIGHT)
	self.title = self.title_box:add(Label({
		font_name = "cjk_bold",
		font_size = 68,
		color = Colors.text,
		text = "Title",
	}))
	self.title:setPosition(0, (TITLE_LINE_HEIGHT - self.title.font:getHeight()) / 2)

	-- Chart name flows after the artist, so a long artist pushes it right instead of overlapping.
	local sub = name:add(FlowContainer({direction = "row", gap = 24, align = "baseline"}))
	self.artist = sub:add(Label({
		font_name = "cjk_regular",
		font_size = 34,
		color = Colors.accent,
		text = "Artist",
	}))
	self.chart_name = sub:add(Label({
		font_name = "cjk_regular",
		font_size = 28,
		color = Colors.text,
		text = "Chart name",
	}))
	sub:fitContent()
	name:fitContent()
	name:setPosition(EDGE, TITLE_TOP)
end

---@private
function ResultV2:createAccuracy()
	-- Left column: how you played.
	self.left = self.content:add(FlowContainer({direction = "column", gap = 32}))
	self.accuracy = self.left:add(ResultAccuracy())
	self.judges = self.left:add(ResultJudges())
	self.run_cells = self.left:add(ValueCells({"COMBO", "PAUSES", "MEAN", "L MISS", "C MISS", "R MISS"}))
	self.left:fitContent()
	self.left:setPosition(EDGE - 5, CONTENT_TOP)

	-- Right column: what the chart is. Fixed width so its left edge doesn't move with the content.
	self.right = self.content:add(FlowContainer({direction = "column", gap = 32}))
	self.difficulty = self.right:add(ResultDifficulty())
	self.facts = self.right:add(ValueCells({"KEYS", "LENGTH", "NOTES", "BPM", "LN"}))
	self.mutators = self.right:add(ResultMutators(COLUMN_RIGHT_WIDTH))
	self.right:fitContent()
	self.right:setWidth(COLUMN_RIGHT_WIDTH)
	self.right:setAlignment(1, 0):addPosition(-EDGE, CONTENT_TOP)
end

---@private
---@param id string
function ResultV2:runCommand(id)
	-- TODO: Using command pallete as a stable API is an interesting idea.
	for _, command in ipairs(self.ui.ui_result_commands) do
		if command.id == id then
			command.callback({})
			return
		end
	end
	error(("result command `%s` does not exist"):format(id))
end

---@private
function ResultV2:createFooter()
	local ui = self.ui
	local footer = self.content:add(View())
	footer:fillWidth(EDGE, EDGE):setHeight(BUTTON_HEIGHT):setAlignmentY(1):addPosition(0, -FOOTER_BOTTOM)

	local function button(text, variant, width, on_click)
		return footer:add(Button(text, on_click, {variant = variant, font_size = 18}))
			:anchorFixed(0, 0, width, BUTTON_HEIGHT)
	end

	self.back_button = button("BACK", "danger", 154, function()
		self:runCommand("ui.result.back")
	end)

	-- Right-aligned, laid out from the edge inwards: Watch, Export Video, Export Replay.
	local x = 0
	for _, item in ipairs({
		{"WATCH", "success", 190, function() self:runCommand("ui.result.watch_replay") end},
		{"EXPORT VIDEO", "secondary", 227, nil},
		{"EXPORT REPLAY", "secondary", 227, nil},
	}) do
		local view = button(item[1], item[2], item[3], item[4])
		view:setAlignmentX(1):addPosition(-x, 0)
		view:setEnabled(item[4] ~= nil)
		x = x + item[3] + BUTTON_GAP
	end
end

---@param inputs gui.Inputs
function ResultV2:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.song_select, true)
	end
end

function ResultV2:updateInfo()
	local chartview = self.ui.game.chartSelector.chartview

	if not chartview then
		self.ui:setScreen(self.ui.main_menu)
		return
	end

	local game = self.ui.game
	local result_controller = game.resultController
	local is_replay_result = result_controller.replay ~= nil
	local result_chartplay = is_replay_result and game.computeContext.chartplay
	local result_rate = result_chartplay and result_chartplay.rate or game.replayBase.rate

	self.chartview_formatter:setChartview(chartview)
	self.chartview_formatter:setTimeRate(result_rate)
	self.chartdiff_formatter:setChartdiff(game.computeContext.chartdiff)
	self.difficulty:bind(self.chartview_formatter, self.chartdiff_formatter)
	self.status:bind(self.chartview_formatter)
	self.mutators:bind(is_replay_result and result_controller.replay_base or game.replayBase)
	local ln = self.chartview_formatter:getLongNoteRatio()
	self.facts:setValues({
		{value = (self.chartview_formatter:getMode())},
		{value = self.chartview_formatter:getDuration()},
		{value = self.chartview_formatter:getNoteCount()},
		{value = self.chartview_formatter:getTempo().avg},
		{value = ln.value, color = ln.color},
	})
	self.right:fitContent()
	self.right:setWidth(COLUMN_RIGHT_WIDTH)
	self.title:setText(chartview.title)
	self.title_box:setSize(self.title.width, TITLE_LINE_HEIGHT)
	self.artist:setText(chartview.artist)
	self.chart_name:setText(self.chartview_formatter:getName() or "")

	local score_engine = self.ui.game.rhythm_engine.score_engine
	local judge_source = score_engine.judgesSource
	local accuracy_source = score_engine.accuracySource
	if not judge_source or not accuracy_source then
		self.left:setVisible(false)
		return
	end
	self.left:setVisible(true)
	-- The selected judge system is created from the resolved timings, so it is authoritative.
	local score_system = judge_source --[[@as rizu.ScoreSystem]]
	assert(score_system.timings)
	local score_system_formatter = ScoreSystemFormatter(score_system)
	self.accuracy:bind(accuracy_source, score_system_formatter)
	self.judges:bind(judge_source, score_system_formatter)

	-- Combo counts a long note twice, so the total is the judgeable count, not the note count.
	-- TODO: IComboSource:getMaxPossibleCombo() should provide this, so score systems can report their own total.
	local combo_source = score_engine.comboSource
	local pauses = result_chartplay and result_chartplay.pause_count or game.rhythm_engine.pause_counter.count
	-- TODO: mean (or std dev) and the miss counts need a pass over all score system events.
	self.run_cells:setValues({
		{value = tostring(combo_source and combo_source:getMaxCombo() or 0), suffix = " / " .. tostring(game.computeContext.chartdiff.judges_count)},
		{value = tostring(pauses), color = pauses > 0 and Colors.danger or nil},
		{value = "0", suffix = " ms"},
		{value = "0"},
		{value = "0"},
		{value = "0"},
	})
	self.left:fitContent()
end

function ResultV2:enter()
	-- Gameplay stops previews; resume the selected Chart's synchronized audio and BGA.
	self.ui.game.selectionCoordinator:activatePreview()

	self.ui.command_registry:pushContext("result_commands", self.ui.result_commands)
	self.ui.command_registry:pushContext("ui_result_commands", self.ui.ui_result_commands)
	self:updateInfo()
	self.composite:fadeIn(0.6, "OutQuint")
end

function ResultV2:exit()
	self.ui.tooltip:setText(nil)
	self.ui.command_registry:popContext("result_commands")
	self.ui.command_registry:popContext("ui_result_commands")
	Screen.exit(self)
	self.composite:fadeOut(0.3, "OutQuint")
end

return ResultV2
