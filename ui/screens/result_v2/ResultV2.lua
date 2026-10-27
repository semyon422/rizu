local Screen = require("gui.Screen")
local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local ShadowCompositeView = require("gui.ShadowCompositeView")
local CompositeView = require("gui.CompositeView")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local IconTextButton = require("ui.views.IconTextButton")
local Background = require("ui.views.Background")
local Panel = require("ui.views.Panel")
local UiConfig = require("ui.UiConfig")
local BgaPreview = require("ui.views.BgaPreview")
local ChartviewFormatter = require("ui.formatters.ChartviewFormatter")
local ResultJudges = require("ui.screens.result_v2.ResultJudges")
local ResultDifficulty = require("ui.screens.result_v2.ResultDifficulty")
local ChartdiffFormatter = require("ui.formatters.ChartdiffFormatter")
local ValueCells = require("ui.screens.result_v2.ValueCells")
local ResultStatus = require("ui.screens.result_v2.ResultStatus")
local ResultMutators = require("ui.screens.result_v2.ResultMutators")
local ScoreList = require("ui.screens.result_v2.ScoreList")
local HitGraph = require("ui.screens.result_v2.HitGraph")
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
local BUTTON_HEIGHT = IconTextButton.HEIGHT
local SCORES_ROWS = 4
local SCORES_FOOTER_GAP = 28
local COLUMN_LEFT_WIDTH = 840
local BUTTON_GAP = 12

---@class ui.screens.result_v2.ResultV2 : gui.Screen
---@operator call: ui.screens.result_v2.ResultV2
---@field ui ui.UserInterface
---@field unsubscribe fun()?
---@field loading_score boolean?
local ResultV2 = Screen + {}

-- Stays above the next screen while fading out: song select fades in an opaque backdrop that would hide it.
ResultV2.draw_over_next_screen = true

---@param ui ui.UserInterface
function ResultV2:new(ui)
	Screen.new(self)
	self.ui = ui

	self.chartview_formatter = ChartviewFormatter(
		ui.api.charts:getSelectedChart(),
		ui.api.settings
	)

	self.chartdiff_formatter = ChartdiffFormatter(
		ui.api.result:getChartdiff(),
		ui.api.settings
	)

	self.composite = self.root:add(CompositeView()):anchorFill(0, 0, 0, 0)

	-- Sharp fullscreen chart art; legibility comes from the scrims below, not from dimming it.
	self.background = self.composite:add(Background(ui.api.media, true))
	self.background:anchorFill(0, 0, 0, 0)
	self.bga_preview = self.composite:add(BgaPreview(ui.api.media)):anchorFill(0, 0, 0, 0)
	-- Darkens the image and the BGA together.
	local darken = self.composite:add(Panel({color = {0, 0, 0, 1}})):anchorFill(0, 0, 0, 0)
	local function setBrightness(brightness) darken:setOpacity(1 - brightness) end
	setBrightness(ui.config:getNumber(UiConfig.keys.result_background_brightness))
	ui.config:subscribeNumber(UiConfig.keys.result_background_brightness, setBrightness)

	self.composite:add(Image(Resources.sprites.result_v2_scrim_horizontal, "fit")):anchorFill(0, 0, 0, 0)
	self.composite:add(Image(Resources.sprites.result_v2_scrim_vertical, "fit")):anchorFill(0, 0, 0, 0)

	-- Everything above the background casts a soft shadow, sprites included.
	self.content = self.composite:add(ShadowCompositeView({blur = 6, opacity = 0.85}))
	self.content:anchorFill(0, 0, 0, 0)

	self:createName()
	self.status = self.content:add(ResultStatus())
	self.status:setAlignment(1, 0):addPosition(-EDGE, STATUS_TOP)
	self:createAccuracy()
	self:createScores()
	self:createHitGraph()
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
	self.run_cells = self.left:add(ValueCells({"COMBO", "NS", "PAUSES"}))
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
function ResultV2:createScores()
	local ui = self.ui
	local scores = self.content:add(FlowContainer({direction = "column", gap = 10}))
	scores:add(Label({
		font_name = "bold",
		font_size = 20,
		color = Colors.muted,
		text = "LEADERBOARD",
	}))
	self.score_list = scores:add(ScoreList(ui.api.scores, ui.localization, ui.api.online))
	self.score_list:setSize(COLUMN_LEFT_WIDTH, ScoreList.getHeightForRows(SCORES_ROWS))
	self.score_list:setOnSelect(function(index) self:openScore(index) end)
	self.score_list:setSelectionMarked(true)
	scores:fitContent()
	scores:setAlignment(0, 1):addPosition(EDGE, -(FOOTER_BOTTOM + BUTTON_HEIGHT + SCORES_FOOTER_GAP))
end

---@private
---@param index integer
function ResultV2:openScore(index)
	local scores = self.ui.api.scores
	-- Two replays computing at once would leave whichever finishes last on screen.
	if self.loading_score then
		return
	end
	scores:select(index)
	if not scores:getSelected() then
		return
	end
	self.loading_score = true
	scores:loadSelectedResult(function()
		self.loading_score = false
		-- A failed load leaves no score, which updateInfo shows as an empty result.
		self:updateInfo()
	end)
end

---@private
function ResultV2:createHitGraph()
	-- Bottom-aligned with the score list on the other side.
	self.hit_graph = self.content:add(HitGraph(self.ui.tooltip, false))
	self.hit_graph:anchorFixed(0, 0, COLUMN_RIGHT_WIDTH, ScoreList.getHeightForRows(SCORES_ROWS))
	self.hit_graph:setAlignment(1, 1):addPosition(-EDGE, -(FOOTER_BOTTOM + BUTTON_HEIGHT + SCORES_FOOTER_GAP))
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

	self.back_button = footer:add(IconTextButton({
		text = "BACK",
		icon = Resources.sprites.icon_undo_2,
		variant = "danger",
		font_size = 18,
		padding_left = 24,
		padding_right = 30,
		on_click = function() self:runCommand("ui.result.back") end,
	}))

	self.rescore_button = footer:add(IconTextButton({
		text = "RESCORE",
		icon = Resources.sprites.icon_calculator,
		font_size = 18,
		on_click = function() self:runCommand("ui.result.open_rescore") end,
	}))
	self.rescore_button:addPosition(self.back_button:getPreferredWidth() + BUTTON_GAP, 0)

	-- Right-aligned, laid out from the edge inwards: Watch, Export Video, Export Replay.
	local x = 0
	for _, item in ipairs({
		{
			text = "WATCH",
			icon = Resources.sprites.icon_play,
			icon_after = true,
			variant = "success",
			font_size = 18,
			gap = 14,
			padding_left = 44,
			padding_right = 34,
			on_click = function() self:runCommand("ui.result.watch_replay") end,
		},
		{
			text = "EXPORT VIDEO",
			icon = Resources.sprites.icon_camera,
			on_click = function() ui.modal_manager:attachVideoExport() end,
		},
		{
			text = "EXPORT REPLAY",
			icon = Resources.sprites.icon_download,
		},
	}) do
		local view = footer:add(IconTextButton(item))
		view:setAlignmentX(1):addPosition(-x, 0)
		view:setEnabled(item.on_click ~= nil)
		x = x + view:getPreferredWidth() + BUTTON_GAP
	end
end

---@param inputs gui.Inputs
function ResultV2:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.song_select, true)
	end
end

function ResultV2:updateInfo()
	local chartview = self.ui.api.charts:getSelectedChart()

	if not chartview then
		self.ui:setScreen(self.ui.main_menu)
		return
	end

	local result = self.ui.api.result
	local chartdiff = result:getChartdiff()

	self.chartview_formatter:setChartview(chartview)
	self.chartview_formatter:setTimeRate(result:getRate())
	self.chartdiff_formatter:setChartdiff(chartdiff)
	self.difficulty:bind(self.chartview_formatter, self.chartdiff_formatter)
	self.status:bind(self.chartview_formatter)
	self.mutators:bind(result:getMutators(), self.ui.api.play)
	local ln = self.chartdiff_formatter:getLongNoteRatio()
	self.facts:setValues({
		{value = (self.chartview_formatter:getMode(chartdiff and chartdiff.inputmode))},
		{value = self.chartdiff_formatter:getDuration()},
		{value = self.chartdiff_formatter:getNoteCount()},
		{value = self.chartview_formatter:getTempo().avg},
		{value = ln.value, color = ln.color},
	})
	self.right:fitContent()
	self.right:setWidth(COLUMN_RIGHT_WIDTH)
	self.title:setText(chartview.title)
	self.title_box:setSize(self.title.width, TITLE_LINE_HEIGHT)
	self.artist:setText(chartview.artist)
	self.chart_name:setText(self.chartview_formatter:getName() or "")

	local has_score = result:hasScore()
	self.left:setVisible(has_score)
	self.hit_graph:setVisible(has_score)
	self.rescore_button:setVisible(has_score)
	if not has_score then
		return
	end
	self.hit_graph:bind(result)
	-- The judging system is created from the resolved timings, so it is authoritative.
	local judging = result:getJudging()
	assert(judging.timings)
	local score_system_formatter = ScoreSystemFormatter(judging --[[@as rizu.ScoreSystem]])
	local accuracy, accuracy_text = result:getAccuracy()
	self.accuracy:bind(accuracy, accuracy_text, score_system_formatter, result:isPassed())
	self.judges:bind(result:getJudgeCounts(), score_system_formatter)

	local max_combo, possible_combo = result:getMaxCombo()
	local pauses = result:getPauseCount()
	local captions = {"COMBO", "NS", "PAUSES"}
	local values = {
		{value = tostring(max_combo), suffix = " / " .. tostring(possible_combo)},
		{value = result:getNormalscoreText() or "-"},
		{value = tostring(pauses), color = pauses > 0 and Colors.danger or nil},
	}
	-- A kind of miss that never happened is not shown.
	local misses = result:getMissCounts()
	for _, kind in ipairs({
		{"L MISS", misses.left},
		{"C MISS", misses.center},
		{"R MISS", misses.right},
		{"S MISS", misses.scratch},
	}) do
		if kind[2] > 0 then
			table.insert(captions, kind[1])
			table.insert(values, {value = tostring(kind[2])})
		end
	end
	self.run_cells:setCaptions(captions)
	self.run_cells:setValues(values)
	self.left:fitContent()
end

function ResultV2:enter()
	local api = self.ui.api
	-- A play stops the previews.
	api.media:startPreview()

	self.unsubscribe = api.scores:on("scores_changed", function(loading)
		-- Rows are replaced once loading finishes; the transient clear while loading is ignored.
		if not loading then
			self.score_list:reload()
		end
	end)
	self:updateInfo()
	self.score_list:reload()
	-- Saving a score doesn't emit anything, so the list is still the one from before the play.
	-- Loading it again emits the event that refreshes the rows.
	api.scores:refresh()
	self.composite:fadeIn(0.6, "OutQuint")
end

function ResultV2:exit()
	self.unsubscribe()
	self.ui.tooltip:setText(nil)
	Screen.exit(self)
	self.composite:fadeOut(0.3, "InOutQuad")
end

return ResultV2
