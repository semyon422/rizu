local just = require("just")
local spherefonts = require("sphere.assets.fonts")
local icons = require("sphere.assets.icons")
local imgui = require("imgui")

local BackgroundView = require("sphere.views.BackgroundView")
local GaussianBlurView = require("sphere.views.GaussianBlurView")

local PointGraphView = require("sphere.views.GameplayView.PointGraphView")
local ScoreListView = require("ui.views.ResultView.ScoreListView")
local ModifierIconGridView = require("ui.views.SelectView.ModifierIconGridView")
local MatchPlayersView = require("sphere.views.GameplayView.MatchPlayersView")
local TextCellImView = require("ui.imviews.TextCellImView")
local Format = require("sphere.views.Format")
local RoundedRectangle = require("ui.views.RoundedRectangle")

local time_util = require("time_util")
local Layout = require("ui.views.ResultView.Layout")

---@param self table
---@return boolean
local function showLoadedScore(self)
	local chartplay = self.game.computeContext.chartplay
	local chartplay = self.game.scoreSelector.chartplay
	if not chartplay or not chartplay then
		return false
	end
	return chartplay.id == chartplay.id
end


---@param w number
---@param h number
---@param _r number?
local function drawFrameRect(w, h, _r)
	local r, g, b, a = love.graphics.getColor()
	love.graphics.setColor(0, 0, 0, 0.8)
	love.graphics.rectangle("fill", 0, 0, w, h, _r or 36)
	love.graphics.setColor(r, g, b, a)
end

---@param w number
---@param h number
---@param _r number?
local function drawFrameRect2(w, h, _r)
	local r, g, b, a = love.graphics.getColor()
	love.graphics.setColor(0.4, 0.4, 0.4, 0.7)
	RoundedRectangle("fill", 0, 0, w, h, _r or 36)
	love.graphics.setColor(r, g, b, a)
end

---@param self table
local function Frames(self)
	local w, h = Layout:move("base")
	love.graphics.setColor(1, 1, 1, 0.2)
	love.graphics.rectangle("fill", 0, 0, w, h)

	w, h = Layout:move("graphs")
	drawFrameRect(w, h)

	love.graphics.setColor(0.1, 0.1, 0.1, 0.8)

	w, h = Layout:move("title_left")
	RoundedRectangle("fill", 0, 0, w, h, 36, false, false, 3)

	w, h = Layout:move("title_sub")
	RoundedRectangle("fill", 0, 0, w, 72, 36, true, true, 2)

	w, h = Layout:move("title_right")
	RoundedRectangle("fill", 0, 0, w, h, 36, false, false, 1)
end

---@param self table
local function Background(self)
	local w, h = Layout:move("base")

	local dim = self.game.configModel.configs.settings.graphics.dim.result
	BackgroundView.game = self.game
	BackgroundView:draw(w, h, dim, 0.01)
end

---@param self table
local function ScoreSources(self)
	local w, h = Layout:move("graphs")
	local padding = 18 * math.sqrt(2)
	love.graphics.translate(padding, h)

	---@type sphere.GameController
	local game = self.game
	local scoreEngine = game.rhythm_engine.score_engine
	if not scoreEngine then
		return
	end
	local replay = game.resultController.replay

	local show = showLoadedScore(self)
	local chartplay = game.scoreSelector.chartplay

	if not scoreEngine.accuracySource then
		return
	end

	local timings, subtimings
	if (show and replay) then
		timings, subtimings = replay.timings, replay.subtimings
	elseif chartplay then
		timings, subtimings = chartplay.timings, chartplay.subtimings
	end

	love.graphics.setColor(0, 0, 0, 0.2)
	love.graphics.rectangle("fill", 0, 0, w, 55)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans", 16))

	imgui.text(("timings: %s, subtimings: %s"):format(timings, subtimings))

	if not show then
		return
	end

	imgui.text(("acc: %s, judges: %s, score: %s, combo: %s, healths: %s"):format(
		scoreEngine.accuracySource:getKey(),
		scoreEngine.judgesSource:getKey(),
		scoreEngine.scoreSource:getKey(),
		scoreEngine.comboSource:getKey(),
		scoreEngine.healthsSource:getKey()
	))
end

---@param self table
local function drawGraph(self)
	local w, h = Layout:move("graphs")
	local padding = 18 * math.sqrt(2) / 2
	love.graphics.translate(padding, padding)
	w = w - padding * 2
	h = h - padding * 2
	self.__index.draw(self, w, h)
end

local _ComboGraph = PointGraphView({
	draw = drawGraph,
	radius = 2,
	backgroundColor = { 0, 0, 0, 0.2 },
	backgroundRadius = 4,
	point = function(self, point)
		local y = 1 - point.base.combo / point.base.notesCount
		return y, 1, 1, 0.25, 1
	end,
	show = showLoadedScore,
})

---@param self table
local function ComboGraph(self)
	_ComboGraph.game = self.game
	_ComboGraph:draw()
end

local _EarlyHitGraph = PointGraphView({
	draw = drawGraph,
	radius = 4,
	backgroundColor = { 1, 1, 1, 1 },
	backgroundRadius = 6,
	point = function(self, point)
		if not point.base.isEarlyHit then
			return
		end
		local y = point.misc.deltaTime / 0.16 / 2 + 0.5
		return y, 0.4, 0.35, 0.8, 1
	end,
	show = showLoadedScore,
})

---@param self table
local function EarlyHitGraph(self)
	_EarlyHitGraph.game = self.game
	_EarlyHitGraph:draw()
end

local perfectColor = { 1, 1, 1, 1 }
local notPerfectColor = { 1, 0.6, 0.4, 1 }
local _HitGraph = PointGraphView({
	draw = drawGraph,
	radius = 2,
	backgroundColor = { 0, 0, 0, 0.2 },
	backgroundRadius = 6,
	point = function(self, point)
		if point.base.isMiss then
			return
		end
		local color = notPerfectColor
		if math.abs(point.misc.deltaTime) <= 0.016 then
			color = perfectColor
		end

		local y = point.misc.deltaTime / 0.16 / 2 + 0.5
		return y, unpack(color)
	end,
	show = showLoadedScore,
})

---@param self table
local function HitGraph(self)
	_HitGraph.game = self.game
	_HitGraph:draw()
end

local _MissGraph = PointGraphView({
	draw = drawGraph,
	radius = 4,
	backgroundColor = { 1, 1, 1, 1 },
	backgroundRadius = 6,
	point = function(self, point)
		if not point.base.isMiss then
			return
		end
		local y = point.misc.deltaTime / 0.16 / 2 + 0.5
		return y, 1, 0.2, 0.2, 1
	end,
	show = showLoadedScore,
})

---@param self table
local function MissGraph(self)
	_MissGraph.game = self.game
	_MissGraph:draw()
end

local _HpGraph = PointGraphView({
	draw = drawGraph,
	radius = 2,
	backgroundColor = { 0, 0, 0, 0.2 },
	backgroundRadius = 4,
	point = function(self, point)
		local value = 0
		local healthsSource = self.game.rhythm_engine.score_engine.healthsSource
		local slice = point[healthsSource:getKey()]
		value = slice.healths / slice.max_healths

		-- local hp = point.hp
		-- for _, h in ipairs(hp) do
		-- 	if h.value > 0 then
		-- 		value = h.value / _hp.max
		-- 		break
		-- 	end
		-- end

		return 1 - value, 0.25, 1, 0.5, 1
	end,
	show = showLoadedScore,
})

---@param self table
local function HpGraph(self)
	_HpGraph.game = self.game
	_HpGraph:draw()
end

---@param self table
local function ScoreList(self)
	local w, h = Layout:move("column3")
	drawFrameRect(w, h)
	love.graphics.setColor(0.4, 0.4, 0.4, 0.7)
	w, h = Layout:move("column3row1")
	drawFrameRect2(w, h)
	love.graphics.setColor(1, 1, 1, 1)

	love.graphics.translate(w - h, 0)
	if imgui.TextButton("replay info", "i", h, h) then
		self.game.ui.gameView:setModal(require("ui.views.ResultView.ReplayInfoModal"))
	end

	w, h = Layout:move("column3row2")

	ScoreListView.game = self.game
	ScoreListView.screenView = self
	ScoreListView:draw(w, h)

	love.graphics.setColor(1, 1, 1, 0.8)
	h = h / ScoreListView.rows
	local c = math.floor(ScoreListView.rows / 2)
	love.graphics.polygon(
		"fill",
		0,
		h * (c + 0.2) + (72 - h) / 2,
		h / 2 * 0.6,
		h * (c + 0.5) + (72 - h) / 2,
		0,
		h * (c + 0.8) + (72 - h) / 2
	)

	w, h = Layout:move("column3row2")
	love.graphics.translate(w - 16, 0)

	local list = ScoreListView
	local count = list:getItemCount() - 1
	local pos = (list.visualItemIndex - 1) / count
	local newScroll = imgui.ScrollBar("slsb", pos, 16, h, count / list.rows)
	if newScroll then
		list:scroll(math.floor(count * newScroll + 1) - list.itemIndex)
	end
end

---@param self table
local function Title(self)
	local chartview = self.game.chartSelector.chartview

	local w, h = Layout:move("title_middle")
	drawFrameRect(w, h)
	love.graphics.translate(22, 15)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans", 36))

	local artist_title = ("%s — %s"):format(chartview.artist, chartview.title)
	local creator_name = ("%s — %s"):format(chartview.creator, chartview.name)
	just.text(artist_title)
	just.text(creator_name)
end

---@param self {game: sphere.GameController}
local function Judgements(self)
	local show = showLoadedScore(self)
	local scoreEngine = self.game.rhythm_engine.score_engine
	if not scoreEngine then
		return
	end
	local chartplay = self.game.scoreSelector.chartplay
	local judgesSource = scoreEngine.judgesSource

	if not judgesSource or not chartplay then
		return
	end

	local padding = 24

	local w, h = Layout:move("column1")
	drawFrameRect(w, h)
	love.graphics.setColor(0.4, 0.4, 0.4, 0.7)
	w, h = Layout:move("column1row1")
	drawFrameRect2(w, h)
	love.graphics.setColor(1, 1, 1, 1)

	local w, h = Layout:move("column1row2")
	love.graphics.translate(padding, padding)

	w = w - padding * 2

	local judgementLists = judgesSource:getJudgeNames()
	local counters = judgesSource:getJudges()

	if not show then
		counters = chartplay.judges
	end

	counters = counters or {}

	local miss = show and scoreEngine.scores.base.missCount or chartplay.miss_count or 0

	local notes = 0
	for _, n in ipairs(counters) do
		notes = notes + n
	end

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans", 24))

	local interval = 5
	local lineHeight = 40

	if show then
		for i, name in ipairs(judgementLists) do
			imgui.ValueBar(w, lineHeight, counters[i] / notes, name, counters[i])
			just.emptyline(interval)
		end
	else
		for i, v in ipairs(counters) do
			imgui.ValueBar(w, lineHeight, v / notes, "", v)
			just.emptyline(interval)
		end
	end

	Layout:move("column1row2")
	love.graphics.translate(padding, -padding + h - lineHeight)

	imgui.ValueBar(w, lineHeight, miss / notes, "miss", miss)
end

---@param self {game: sphere.GameController}
local function JudgementsDropdown(self)
	local show = showLoadedScore(self)
	local chartplay = self.game.scoreSelector.chartplay
	local chartview = self.game.chartSelector.chartview

	local w, h = Layout:move("column1row1")
	h = 60

	local size = 1 / 2
	love.graphics.translate(w * (1 - size) - 26, (72 - h) / 2)

	love.graphics.setFont(spherefonts.get("Noto Sans", 20))

	imgui.setSize(w, h, w / 2, h / 2)

	---@type sea.ReplayBase
	local replayBase = self.game.replayBase

	if not show then
		if not chartplay then
			return
		end
		replayBase = chartplay
	end

	local timings = replayBase.timings or chartview.timings
	local subtimings = replayBase.subtimings

	local text = ""
	if timings then
		text = timings.name .. " " .. timings.data
	end
	if subtimings then
		text = text .. " " .. subtimings.name .. " " .. subtimings.data
	end

	if imgui.TextButton("timings modal", text, w * size, h) then
		self.game.ui.gameView:setModal(require("ui.views.SelectView.TimingsSelectorViewModal"))
	end
end

---@param self {game: sphere.GameController}
local function JudgementsAccuracy(self)
	local show = showLoadedScore(self)
	local chartplay = self.game.scoreSelector.chartplay

	if not show or not chartplay then
		return
	end

	local scoreEngine = self.game.rhythm_engine.score_engine
	if not scoreEngine then
		return
	end

	local w, h = Layout:move("column1row1")
	love.graphics.translate(36, 0)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans Mono", 32))
	imgui.Label("j.acc", scoreEngine.accuracySource:getAccuracyString(), h)
end

---@param self table
local function NotechartInfo(self)
	local erfunc = require("chart.scoring.erfunc")
	local ratingHitTimingWindow = self.game.configModel.configs.settings.gameplay.ratingHitTimingWindow

	---@type sphere.GameController
	local game = self.game

	local rhythm_engine = game.rhythm_engine
	local computeContext = game.computeContext

	if not rhythm_engine.score_engine then
		return
	end

	local normalscore = rhythm_engine.score_engine.scores.normalscore

	local chartview = game.chartSelector.chartview
	local chartplay = game.scoreSelector.chartplay
	local scoreEngine = rhythm_engine.score_engine
	local replay = game.resultController.replay

	if not chartplay then
		return
	end

	local top_chartplay = self.game.scoreSelector.store:get(1)
	if top_chartplay == chartplay then
		top_chartplay = self.game.scoreSelector.store:get(2)
	end
	if not top_chartplay then
		top_chartplay = chartplay
	end

	local chartplay = self.game.computeContext.chartplay
	if not chartplay then
		return
	end

	local show = showLoadedScore(self)
	if show and (not replay or not computeContext.chartdiff or not computeContext.chart) then
		show = false
	end

	local baseTimeRate = show and replay.rate or chartplay.rate
	local const = show and replay.const or chartplay.const

	local baseBpm = chartview.tempo
	local baseLength = chartview.duration or 0
	local baseDifficulty = chartview.difficulty
	local baseInputMode = chartview.inputmode

	local bpm = baseBpm * chartplay.rate
	local length = baseLength / chartplay.rate
	local difficulty = show and computeContext.chartdiff.enps_diff or chartplay.difficulty
	local inputMode = show and tostring(computeContext.chart.inputMode) or chartplay.inputmode

	local w, h = Layout:move("title_left")
	love.graphics.translate(22, 15)

	w = w - 44
	local wr = 0.70

	TextCellImView(w * (1 - wr), 55, "right", "notes", chartview.notes_count)
	just.sameline()
	TextCellImView(
		w * wr,
		55,
		"right",
		"duration",
		length == baseLength and time_util.format(baseLength)
			or ("%s→%s"):format(time_util.format(baseLength), time_util.format(length))
	)

	TextCellImView(w * (1 - wr), 55, "right", "level", chartview.level)
	just.sameline()
	TextCellImView(
		w * wr,
		55,
		"right",
		"bpm",
		bpm == baseBpm and math.floor(baseBpm + 0.5)
			or ("%d→%d"):format(math.floor(baseBpm + 0.5), math.floor(bpm + 0.5))
	)

	w, h = Layout:move("title_sub")
	love.graphics.translate(0, 8)

	local font = spherefonts.get("Noto Sans Mono", 36)
	font:setFallbacks(spherefonts.get("Noto Sans", 36))
	love.graphics.setFont(font)

	just.indent(36)
	just.text(("%0.3fx"):format(baseTimeRate))
	if const then
		just.sameline()
		just.text("c")
	end

	local hp = scoreEngine.scores.hp
	if show and hp then
		just.sameline()
		just.offset(0)

		local _h
		if not hp then
			return
		end
		for _, h in ipairs(hp) do
			if h.value > 0 then
				_h = h
				break
			end
		end

		local text = "fail"
		if _h then
			text = _h.notes .. "hp"
		end
		just.text(text, w - 72, true)
	end

	w, h = Layout:move("middle")
	drawFrameRect(w, h)
	love.graphics.setColor(0.4, 0.4, 0.4, 0.3)
	w, h = Layout:move("middle_sub")
	RoundedRectangle("fill", 0, 0, w, 72, 36, false, false, 2)
	love.graphics.setColor(1, 1, 1, 1)

	local score = not show and chartplay.score
		or erfunc.erf(ratingHitTimingWindow / (normalscore.accuracyAdjusted * math.sqrt(2))) * 10000
	if score ~= score then
		score = 0
	end
	local accuracyValue = show and normalscore.accuracyAdjusted or chartplay.accuracy
	local accuracy = Format.accuracy(accuracyValue)

	local rating = chartplay.rating

	if chartplay.id == chartplay.id then
		local s = erfunc.erf(ratingHitTimingWindow / (normalscore.accuracyAdjusted * math.sqrt(2)))
		rating = s * rhythm_engine.chartdiff.enps_diff
	end

	local bestScore = ("%d"):format(top_chartplay.score)
	local bestAccuracy = Format.accuracy(top_chartplay.accuracy)
	local bestRating = Format.difficulty(top_chartplay.rating)

	local deltaScore = score - top_chartplay.score
	local deltaAccuracy = accuracyValue - top_chartplay.accuracy
	local deltaRating = rating - top_chartplay.rating
	if deltaScore >= 0 then
		deltaScore = "+" .. ("%d"):format(deltaScore)
	else
		deltaScore = ("%d"):format(deltaScore)
	end
	if deltaAccuracy >= 0 then
		deltaAccuracy = "+" .. Format.accuracy(deltaAccuracy)
	else
		deltaAccuracy = Format.accuracy(deltaAccuracy)
	end
	if deltaRating >= 0 then
		deltaRating = "+" .. Format.difficulty(deltaRating)
	else
		deltaRating = Format.difficulty(deltaRating)
	end

	w, h = Layout:move("middle")
	love.graphics.translate(42, 5)
	w = w - 42 * 2

	local a, b = 6, 28
	-------------------------------

	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
	just.text("rating")
	just.sameline()
	just.offset(w - 240)

	love.graphics.setFont(spherefonts.get("Noto Sans Mono", 54))
	just.text(" " .. Format.difficulty(rating))
	just.sameline()

	love.graphics.setFont(spherefonts.get("Noto Sans Mono", 24))
	just.indent(10)
	local offset = just.offset()
	love.graphics.translate(0, a)
	just.text(bestRating)
	just.sameline()
	just.offset(offset)
	love.graphics.translate(0, b)
	just.text(deltaRating)
	love.graphics.translate(0, -a - b)

	-------------------------------

	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
	just.text("score")
	just.sameline()
	just.offset(w - 240)

	love.graphics.setFont(spherefonts.get("Noto Sans Mono", 54))
	just.text((" %d"):format(score))
	just.sameline()

	love.graphics.setFont(spherefonts.get("Noto Sans Mono", 24))
	just.indent(10)
	local offset = just.offset()
	love.graphics.translate(0, a)
	just.text(bestScore)
	just.sameline()
	just.offset(offset)
	love.graphics.translate(0, b)
	just.text(deltaScore)
	love.graphics.translate(0, -a - b)

	-------------------------------

	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
	just.text("accuracy")
	just.sameline()
	just.offset(w - 240)

	love.graphics.setFont(spherefonts.get("Noto Sans Mono", 54))
	just.text(accuracy)
	just.sameline()

	love.graphics.setFont(spherefonts.get("Noto Sans Mono", 24))
	just.indent(10)
	local offset = just.offset()
	love.graphics.translate(0, a)
	just.text(bestAccuracy)
	just.sameline()
	just.offset(offset)
	love.graphics.translate(0, b)
	just.text(deltaAccuracy)
	love.graphics.translate(0, -a - b)

	-------------------------------

	local font = spherefonts.get("Noto Sans Mono", 40)
	font:setFallbacks(spherefonts.get("Noto Sans", 40))
	love.graphics.setFont(font)

	local textInputMode = inputMode == baseInputMode and Format.inputMode(baseInputMode)
		or ("%s→%s"):format(Format.inputMode(baseInputMode), Format.inputMode(inputMode))
	local textDifficulty = difficulty == baseDifficulty and Format.difficulty(baseDifficulty)
		or ("%s→%s"):format(Format.difficulty(baseDifficulty), Format.difficulty(difficulty))

	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
	just.text("input mode")
	just.sameline()
	just.offset(0)

	love.graphics.setFont(spherefonts.get("Noto Sans Mono", 40))
	just.text(textInputMode, w, true)

	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
	just.text("difficulty")
	just.sameline()
	just.offset(0)

	love.graphics.setFont(spherefonts.get("Noto Sans Mono", 40))
	just.text(textDifficulty, w, true)

	w, h = Layout:move("graphs_sup_left")
	love.graphics.setColor(0, 0, 0, 0.8)
	RoundedRectangle("fill", 0, 0, w, h, { 36, h / 2, 36, h / 2 }, false, true)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.translate(22, 0)

	w = (w - 44) / 5

	just.row(true)

	local mean = show and normalscore.normalscore.mean or chartplay.mean or 0
	TextCellImView(w, 55, "right", "mean", ("%0.1f"):format(mean * 1000))

	-- local earlylate = show and scoreEngine.scores.misc.earlylate or chartplay.earlylate
	-- if earlylate == 0 or earlylate ~= earlylate then
	-- 	earlylate = "undef"
	-- elseif earlylate > 1 then
	-- 	earlylate = ("-%d%%"):format((earlylate - 1) * 100)
	-- elseif earlylate < 1 then
	-- 	earlylate = ("%d%%"):format((1 / earlylate - 1) * 100)
	-- end
	-- TextCellImView(w, 55, "right", "early/late", earlylate)

	TextCellImView(w, 55, "right", "pauses", chartplay.pause_count)

	if show then
		local adjustRatio = normalscore.adjustRatio
		adjustRatio = adjustRatio ~= adjustRatio and "nan" or ("%d%%"):format((1 - adjustRatio) * 100)
		TextCellImView(w, 55, "right", "adjust", adjustRatio)

		TextCellImView(w, 55, "right", "spam", scoreEngine.scores.base.earlyHitCount)
		TextCellImView(w, 55, "right", "max error", ("%d"):format(scoreEngine.scores.misc.maxDeltaTime * 1000))
	end

	just.row()
end

---@param self table
local function ModifierIconGrid(self)
	local w, h = Layout:move("middle_sub")
	-- drawFrameRect(w, h)
	love.graphics.translate(36, 0)

	local chartSelector = self.game.chartSelector
	local replay = self.game.resultController.replay
	local chartplay = self.game.scoreSelector.chartplay

	local modifiers = (showLoadedScore(self) and replay) and replay.modifiers or (chartplay and chartplay.modifiers)

	if not modifiers then
		return
	end

	ModifierIconGridView.game = self.game
	ModifierIconGridView:draw(modifiers, w - 72, h, h, true)
end

---@param self table
local function BottomScreenMenu(self)
	local w, h = Layout:move("title_right")

	love.graphics.translate(0, 72 / 2)
	if imgui.IconOnlyButton("back", icons("clear"), 72, 0.618) then
		self:changeScreen("selectView")
	end

	love.graphics.setFont(spherefonts.get("Noto Sans", 24))

	local chartplay = self.game.scoreSelector.chartplay
	local chartplay = self.game.computeContext.chartplay

	w, h = Layout:move("graphs_sup_right")
	love.graphics.setColor(0, 0, 0, 0.8)
	RoundedRectangle("fill", 0, 0, w, h, { h / 2, 36, h / 2, 36 }, true, false)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.translate(55, 0)

	just.row(true)
	if imgui.TextOnlyButton("retry", "retry", 72 * 1.5, h) then
		self:play("retry")
	end
	if imgui.TextOnlyButton("replay", "watch", 72 * 1.5, h) then
		self:play("replay")
	end
	if chartplay and chartplay and chartplay.id == chartplay.id and not chartplay.file then
		if imgui.TextOnlyButton("submit", "resubmit", 72 * 2, h) then
			self.game.onlineModel.onlineScoreManager:submit(self.game.chartSelector.chartview, chartplay.replay_hash)
		end
	end
	if imgui.TextOnlyButton("to osr", "to osr", 72 * 1.5, h) then
		error("fix this")
		-- local chart, chartmeta = self.game.chartSelector:loadChartAbsolute()
		-- self.game.resultController:saveOsr(chartmeta)
	end
	just.row()
end

---@param self table
local function MatchPlayers(self)
	Layout:move("column1")
	MatchPlayersView.game = self.game
	MatchPlayersView:draw()
end

return function(self)
	GaussianBlurView:draw(self.game.configModel.configs.settings.graphics.blur.result)
	Background(self)
	GaussianBlurView:draw(self.game.configModel.configs.settings.graphics.blur.result)
	Frames(self)
	Title(self)
	NotechartInfo(self)
	ModifierIconGrid(self)
	ScoreList(self)
	HitGraph(self)
	ComboGraph(self)
	HpGraph(self)
	MissGraph(self)
	EarlyHitGraph(self)
	ScoreSources(self)
	BottomScreenMenu(self)
	Judgements(self)
	JudgementsDropdown(self)
	JudgementsAccuracy(self)
	MatchPlayers(self)
end
