local class = require("class")
local thread = require("thread")
local ChartfileReader = require("rizu.library.ChartfileReader")
local IidxDecodeContext = require("chart.format.iidx.DecodeContext")
local Chartdiff = require("sea.chart.Chartdiff")
local Chartmeta = require("sea.chart.Chartmeta")
local DiffcalcContext = require("chart.difficulty.DiffcalcContext")
local ReplayBase = require("sea.replays.ReplayBase")
local Restorer = require("chart.refchart.Restorer")

---@class rizu.GameplayChart
---@operator call: rizu.GameplayChart
local GameplayChart = class()

---@param config sphere.SettingsConfig
---@param fs fs.IFilesystem
---@param chartview table
function GameplayChart:new(config, fs, chartview)
	self.config = config
	self.fs = fs
	self.chartview = chartview
end

---@return {location_path: string, location_prefix: string?, chartfile_name: string, index: integer}
function GameplayChart:getChartviewData()
	local chartview = self.chartview
	return {
		location_path = chartview.location_path,
		location_prefix = chartview.location_prefix,
		chartfile_name = chartview.chartfile_name,
		index = chartview.index,
	}
end

local prepare_async = thread.async(function(chartview_data)
	local ChartfileReaderAsync = require("rizu.library.ChartfileReader")
	local IidxDecodeContextAsync = require("chart.format.iidx.DecodeContext")
	local LoveFilesystem = require("fs.LoveFilesystem")

	local fs = LoveFilesystem()

	local data = assert(ChartfileReaderAsync.read(fs, chartview_data.location_path))

	local context = IidxDecodeContextAsync.fromLocation(
		fs,
		chartview_data.location_prefix,
		chartview_data.chartfile_name
	)

	return data, context
end)

local compute_async = thread.async(function(chartview_data, data, context, replay_base_data, gameplay_config)
	local ComputeContext = require("sea.compute.ComputeContext")
	local RefChartAsync = require("chart.refchart.RefChart")
	local ReplayBaseAsync = require("sea.replays.ReplayBase")

	local replay_base = ReplayBaseAsync()
	replay_base:importReplayBase(replay_base_data)

	local compute_context = ComputeContext()
	assert(compute_context:fromFileData(
		chartview_data.chartfile_name,
		data,
		chartview_data.index,
		context,
		nil,
		true
	))

	compute_context:applyModifierReorder(replay_base)
	compute_context:computeBase(replay_base)
	compute_context:applyTempo(gameplay_config.tempoFactor, gameplay_config.primaryTempo)
	if gameplay_config.autoKeySound then
		compute_context:applyAutoKeysound()
	end
	if gameplay_config.swapVelocityType then
		compute_context:swapVelocityType()
	end

	return {
		refchart = RefChartAsync(assert(compute_context.chart)),
		chartmeta = compute_context.chartmeta,
		chartdiff = compute_context.chartdiff,
		state = compute_context.state,
		simplified_notes = compute_context.diffcalc_context:getSimplifiedNotes(),
		replay_base = {
			modifiers = replay_base.modifiers,
			columns_order = replay_base.columns_order,
		},
	}
end)

---@param replayBase sea.ReplayBase
---@param ctx sea.ComputeContext
function GameplayChart:computeLoaded(replayBase, ctx)
	local config = self.config

	ctx:applyModifierReorder(replayBase)

	ctx:computeBase(replayBase)

	ctx:applyTempo(config.gameplay.tempoFactor, config.gameplay.primaryTempo)
	if config.gameplay.autoKeySound then
		ctx:applyAutoKeysound()
	end
	if config.gameplay.swapVelocityType then
		ctx:swapVelocityType()
	end
end

---@param replayBase sea.ReplayBase
---@param ctx sea.ComputeContext
---@param data string
---@param context table?
function GameplayChart:loadPrepared(replayBase, ctx, data, context)
	local chartview = self.chartview

	assert(ctx:fromFileData(chartview.chartfile_name, data, chartview.index, context, nil, true))

	self:computeLoaded(replayBase, ctx)
end

---@param replayBase sea.ReplayBase
---@param ctx sea.ComputeContext
function GameplayChart:load(replayBase, ctx)
	local chartview = self.chartview
	local fs = self.fs

	local data = assert(ChartfileReader.read(fs, chartview.location_path))

	local context = IidxDecodeContext.fromLocation(fs, chartview.location_prefix, chartview.chartfile_name)

	self:loadPrepared(replayBase, ctx, data, context)
end

---@param replayBase sea.ReplayBase
---@param ctx sea.ComputeContext
function GameplayChart:loadAsync(replayBase, ctx)
	local data, context = self:prepareAsync()
	self:loadPrepared(replayBase, ctx, data, context)
end

---@param replay_base sea.ReplayBase
---@return table
local function getReplayBaseData(replay_base)
	local data = {}
	for key in pairs(ReplayBase.struct) do
		data[key] = replay_base[key]
	end
	return data
end

---@param replayBase sea.ReplayBase
---@param data string
---@param context table?
---@return table
function GameplayChart:computeAsync(replayBase, data, context)
	local gameplay = self.config.gameplay
	local gameplay_config = {
		tempoFactor = gameplay.tempoFactor,
		primaryTempo = gameplay.primaryTempo,
		autoKeySound = gameplay.autoKeySound,
		swapVelocityType = gameplay.swapVelocityType,
	}

	return compute_async(
		self:getChartviewData(),
		data,
		context,
		getReplayBaseData(replayBase),
		gameplay_config
	)
end

---@param replayBase sea.ReplayBase
---@param ctx sea.ComputeContext
---@param result table
function GameplayChart:applyComputed(replayBase, ctx, result)
	ctx.chart = Restorer():restore(result.refchart)

	ctx.chartmeta = setmetatable(result.chartmeta, Chartmeta)
	ctx.chartdiff = setmetatable(result.chartdiff, Chartdiff)
	ctx.state = result.state
	ctx.chartdiff_fast = false

	local diffcalc_context = DiffcalcContext()
	diffcalc_context:new(ctx.chartdiff, ctx.chart, replayBase.rate)
	diffcalc_context.notes = result.simplified_notes
	ctx.diffcalc_context = diffcalc_context

	replayBase.modifiers = result.replay_base.modifiers
	replayBase.columns_order = result.replay_base.columns_order
end

---@return string data
---@return table? context
function GameplayChart:prepareAsync()
	return prepare_async(self:getChartviewData())
end

return GameplayChart
