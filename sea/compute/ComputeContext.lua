local class = require("class")
local valid = require("valid")
local table_util = require("table_util")
local path_util = require("path_util")
local ChartFactory = require("chart.format.notechart.ChartFactory")
local DifficultyModel = require("chart.difficulty.DifficultyModel")
local ModifierModel = require("sphere.models.ModifierModel")
local Chartdiff = require("sea.chart.Chartdiff")
local ColumnsOrder = require("sea.chart.ColumnsOrder")
local ModifiersMetaState = require("sea.compute.ModifiersMetaState")
local TempoRange = require("chart.format.notechart.TempoRange")
local Note = require("chart.model.notes.Note")
local Notes = require("chart.model.notes.Notes")
local RhythmEngine = require("rizu.engine.RhythmEngine")
local ChartplayComputedFactory = require("rizu.engine.ChartplayComputedFactory")
local ReplayPlayer = require("rizu.engine.replay.ReplayPlayer")

---@class sea.ComputeContext
---@operator call: sea.ComputeContext
---@field chart_chartmetas {chart: chart.Chart, chartmeta: sea.Chartmeta}[]?
---@field chart chart.Chart?
---@field chartmeta sea.Chartmeta?
---@field chartdiff sea.Chartdiff?
---@field chartplay sea.Chartplay?
local ComputeContext = class()

function ComputeContext:new()
	self.difficultyModel = DifficultyModel()
end

---@param name string
---@param data string
---@param index integer
---@param context table?
---@param skip_absolute boolean?
---@param selected_only boolean?
---@return {chart: chart.Chart, chartmeta: sea.Chartmeta}?
---@return string?
function ComputeContext:fromFileData(name, data, index, context, skip_absolute, selected_only)
	local result_index = index
	if selected_only and path_util.ext(name, true) == "1" then
		context = table_util.copy(context or {})
		context.selected_index = index
		result_index = 1
	end

	local ccm, err = ChartFactory:getCharts(name, data, nil, context)
	if not ccm then
		return nil, "get charts: " .. err
	end
	self.chart_chartmetas = ccm
	self.chart = ccm[result_index].chart
	self.chartmeta = ccm[result_index].chartmeta
	if not skip_absolute then
		self:toAbsolute()
	end
	return {
		chart = self.chart,
		chartmeta = self.chartmeta,
	}
end

---@return chart.Chart?
---@return sea.Chartmeta?
function ComputeContext:toAbsolute()
	self.chart.layers.main:toAbsolute()
end

---@param replayBase sea.ReplayBase
---@param inputMode chart.InputMode?
function ComputeContext:applyModifierReorder(replayBase, inputMode)
	if not inputMode then
		local chart = assert(self.chart)
		inputMode = chart.inputMode
	end

	local state = ModifiersMetaState(inputMode)
	ModifierModel:applyMeta(replayBase.modifiers, state)

	local modifiers = table_util.copy(replayBase.modifiers)
	for i = #modifiers, #modifiers - state.reorders + 1, -1 do
		table.remove(modifiers, i)
	end
	replayBase.modifiers = modifiers

	local co = ColumnsOrder(state.inputMode)
	co:apply(state.columns_order.map)
	co:apply(ColumnsOrder(state.inputMode, replayBase.columns_order).map)

	replayBase.columns_order = co:export()
end

---@param chart chart.Chart
---@param rate number
---@return sea.Chartdiff
---@return chart.DiffcalcContext
function ComputeContext:computeChartdiff(chart, rate)
	local chartdiff = {
		mode = "mania",
		rate = rate,
		inputmode = tostring(chart.inputMode),
	}
	setmetatable(chartdiff, Chartdiff)
	---@cast chartdiff sea.Chartdiff
	local diffcalc_context = self.difficultyModel:compute(chartdiff, chart, rate)

	return chartdiff, diffcalc_context
end

---@param replayBase sea.ReplayBase
---@return sea.Chartdiff
---@return sea.ModifiersMetaState
---@return chart.DiffcalcContext
function ComputeContext:computeBase(replayBase)
	local chart = assert(self.chart)
	local chartmeta = assert(self.chartmeta)

	local state = ModifiersMetaState(chart.inputMode)

	ModifierModel:applyMeta(replayBase.modifiers, state)
	ModifierModel:apply(replayBase.modifiers, chart)

	assert(state.reorders == 0, "ending reorder modifiers")

	if replayBase.tap_only then
		self:applyTapOnly()
	end

	local chartdiff, diffcalc_context = self:computeChartdiff(chart, replayBase.rate)

	chartdiff.modifiers = replayBase.modifiers
	chartdiff.hash = chartmeta.hash
	chartdiff.index = chartmeta.index

	assert(valid.format(chartdiff:validate()))

	self.chartdiff = chartdiff
	self.state = state
	self.diffcalc_context = diffcalc_context

	self:applyColumnOrder(replayBase.columns_order)

	return chartdiff, state, diffcalc_context
end

---@param replay sea.Replay
---@return sea.ChartplayComputed?
---@return string?
function ComputeContext:computeReplay(replay)
	local chartmeta = assert(self.chartmeta)
	local chartdiff = assert(self.chartdiff)
	local state = assert(self.state)
	local diffcalc_context = assert(self.diffcalc_context)

	local rhythm_engine = RhythmEngine()

	rhythm_engine:setChart(self.chart, chartmeta, chartdiff)
	rhythm_engine:load()
	rhythm_engine:setGlobalTime(0)
	rhythm_engine:play()

	local timings = assert(replay.timings or chartmeta.timings)

	-- variable unranked
	rhythm_engine:setWindUp(state.windUp)
	rhythm_engine:setTimings(timings, replay.subtimings)
	rhythm_engine:setTimingValues(replay.timing_values)
	rhythm_engine:setRate(replay.rate)
	rhythm_engine:setNearest(replay.nearest)
	rhythm_engine:setConst(replay.const)

	self:computePlay(rhythm_engine, replay.frames)

	local cc_factory = ChartplayComputedFactory(chartdiff, diffcalc_context, rhythm_engine.score_engine)
	local chartplay_computed = cc_factory:getChartplayComputed()

	return chartplay_computed
end

---@param rhythm_engine rizu.RhythmEngine
---@param frames rizu.ReplayFrame[]
function ComputeContext:computePlay(rhythm_engine, frames)
	local p = ReplayPlayer(frames)

	local frame = p:play(math.huge)
	while frame do
		rhythm_engine:setTime(frame.time)
		rhythm_engine:receive(frame.event)
		frame = p:play(math.huge)
	end

	rhythm_engine:setTime(math.huge)
end

---@see sphere.LogicalNoteFactory
function ComputeContext:applyTapOnly()
	local chart = assert(self.chart)

	local long_types = table_util.invert({
		"hold",
		"laser",
		"drumroll",
	})

	for _, note in ipairs(chart.notes:getLinkedNotes()) do
		local t = note:getType()
		if long_types[t] then
			if note.endNote then
				note.endNote.type = "ignore"
			end
			note:unlink()
			note:setType("tap")
		end
	end
end

---@param columns_order integer[]?
function ComputeContext:applyColumnOrder(columns_order)
	if not columns_order then
		return
	end

	local chart = assert(self.chart)
	local co = ColumnsOrder(chart.inputMode, columns_order)
	local map = co.map

	local new_notes = Notes()
	for _, note in chart.notes:iter() do
		note.column = map[note.column] or note.column
		new_notes:insert(note)
	end
	new_notes:compute()
	chart.notes = new_notes
end

---@param chart chart.Chart
---@param tempo number
local function applyTempo(chart, tempo)
	for _, visual in ipairs(chart:getVisuals()) do
		visual.primaryTempo = tempo
		visual:compute()
	end
end

function ComputeContext:swapVelocityType()
	local chart = assert(self.chart)
	for _, visual in ipairs(chart:getVisuals()) do
		visual.tempoMultiplyTarget = "local"
		for _, vp in ipairs(visual.points) do
			local vel = vp._velocity
			if vel then
				vel.localSpeed, vel.currentSpeed = vel.currentSpeed, vel.localSpeed
			end
		end
		visual:compute()
	end
end

---@param tempoFactor string
---@param primaryTempo number
function ComputeContext:applyTempo(tempoFactor, primaryTempo)
	local chart = assert(self.chart)
	local chartmeta = assert(self.chartmeta)
	local chartdiff = assert(self.chartdiff)

	if tempoFactor == "primary" then
		applyTempo(chart, primaryTempo)
		return
	end

	if tempoFactor == "average" and chartmeta.tempo_avg then
		applyTempo(chart, chartmeta.tempo_avg)
		return
	end

	local start_time = chartdiff.start_time
	local end_time = start_time + chartdiff.duration

	local t = {}
	t.average, t.minimum, t.maximum = TempoRange:find(chart, start_time, end_time)

	applyTempo(chart, t[tempoFactor])
end

function ComputeContext:applyAutoKeysound()
	local chart = assert(self.chart)
	for _, note in chart.notes:iter() do
		if note.type == "tap" or note.type == "hold" then
			local soundNote = chart.notes:get(note.visualPoint, "auto")
			if not soundNote then
				soundNote = Note(note.visualPoint, "auto", "sample")
				chart.notes:insert(soundNote)
				soundNote.data.sounds = {}
			end

			if note.data.sounds then
				for _, t in ipairs(note.data.sounds) do
					table.insert(soundNote.data.sounds, t)
				end
				note.data.sounds = {}
			end
		end
	end
	chart.notes:compute()
end

return ComputeContext
