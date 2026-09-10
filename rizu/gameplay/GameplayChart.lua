local NativeMode = require("chart.model.NativeMode")
local SdvxPreparation = require("rizu.gameplay.sdvx.Preparation")
local TaikoPreparation = require("rizu.gameplay.taiko.Preparation")
local CatchPreparation = require("rizu.gameplay.catch.Preparation")
local AimPreparation = require("rizu.gameplay.aim.Preparation")
local class = require("class")
local thread = require("thread")
local ChartfileReader = require("rizu.library.ChartfileReader")
local IidxDecodeContext = require("chart.format.iidx.DecodeContext")
local Chartdiff = require("sea.chart.Chartdiff")
local Chartmeta = require("sea.chart.Chartmeta")
local DiffcalcContext = require("chart.difficulty.DiffcalcContext")
local ReplayBase = require("sea.replays.ReplayBase")
local Restorer = require("chart.refchart.Restorer")
local Settings = require("rizu.config.Settings")

---@class rizu.GameplayChartviewData
---@field location_path string
---@field location_prefix string?
---@field chartfile_name string
---@field index integer

---@class rizu.GameplayChartview: rizu.GameplayChartviewData

---@class rizu.GameplayChartConfig
---@field tempoFactor number
---@field primaryTempo number
---@field autoKeySound boolean
---@field swapVelocityType boolean

---@class rizu.GameplayChartReplayBaseData
---@field modifiers sea.Modifier[]
---@field columns_order integer[]?

---@class rizu.GameplayChartComputeResult
---@field refchart refchart.RefChart
---@field chartmeta sea.Chartmeta
---@field chartdiff sea.Chartdiff
---@field state sea.ModifiersMetaState
---@field simplified_notes table
---@field replay_base rizu.GameplayChartReplayBaseData

---@class rizu.GameplayChart
---@operator call: rizu.GameplayChart
---@field chartview rizu.GameplayChartview
local GameplayChart = class()

---@param settings rizu.config.Config
---@param fs fs.IFilesystem
---@param chartview rizu.GameplayChartview
function GameplayChart:new(settings, fs, chartview)
	self.settings = settings
	self.fs = fs
	self.chartview = chartview
end

---@return rizu.GameplayChartviewData
function GameplayChart:getChartviewData()
	local chartview = self.chartview
	return {
		location_path = chartview.location_path,
		location_prefix = chartview.location_prefix,
		chartfile_name = chartview.chartfile_name,
		index = chartview.index,
	}
end

---@param chartview_data rizu.GameplayChartviewData
---@return string
---@return table?
local function prepare(chartview_data)
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
end

local prepare_async = thread.async(prepare)

---@param chartview_data rizu.GameplayChartviewData
---@param data string
---@param context table?
---@param replay_base_data sea.ReplayBase
---@param gameplay_config rizu.GameplayChartConfig
---@return rizu.GameplayChartComputeResult|{error: string}
function GameplayChart.compute(chartview_data, data, context, replay_base_data, gameplay_config)
	local NativeModeAsync = require("chart.model.NativeMode")
	local ComputeContext = require("sea.compute.ComputeContext")
	local RefChartAsync = require("chart.refchart.RefChart")
	local ReplayBaseAsync = require("sea.replays.ReplayBase")
	local SdvxPreparationAsync = require("rizu.gameplay.sdvx.Preparation")
	local TaikoPreparationAsync = require("rizu.gameplay.taiko.Preparation")
	local CatchPreparationAsync = require("rizu.gameplay.catch.Preparation")
	local AimPreparationAsync = require("rizu.gameplay.aim.Preparation")

	local replay_base = ReplayBaseAsync()
	replay_base:importReplayBase(replay_base_data)

	local compute_context = ComputeContext()
	local ok, decoded, decode_error = pcall(compute_context.fromFileData, compute_context,
		chartview_data.chartfile_name,
		data,
		chartview_data.index,
		context,
		nil,
		true
	)
	if not ok then
		return {error = tostring(decoded)}
	elseif not decoded then
		return {error = assert(decode_error)}
	end

	local mode_ok, mode = pcall(NativeModeAsync.get, compute_context.chart, compute_context.chartmeta)
	if not mode_ok then return {error = tostring(mode)} end
	if mode == "sdvx" then
		local prepared, err = pcall(SdvxPreparationAsync.compute, compute_context, replay_base)
		if not prepared then return {error = tostring(err)} end
	elseif mode == "taiko" then
		local prepared, err = pcall(TaikoPreparationAsync.compute, compute_context, replay_base)
		if not prepared then return {error = tostring(err)} end
	elseif mode == "catch" then
		local prepared, err = pcall(CatchPreparationAsync.compute, compute_context, replay_base)
		if not prepared then return {error = tostring(err)} end
	elseif mode == "osu" then
		local ok, err = pcall(AimPreparationAsync.compute, compute_context, replay_base)
		if not ok then
			return {error = tostring(err)}
		end
	else
		compute_context:applyModifierReorder(replay_base)
		compute_context:computeBase(replay_base)
		compute_context:applyTempo(gameplay_config.tempoFactor, gameplay_config.primaryTempo)
		if gameplay_config.autoKeySound then
			compute_context:applyAutoKeysound()
		end
		if gameplay_config.swapVelocityType then
			compute_context:swapVelocityType()
		end
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
end

local compute_async = thread.async(GameplayChart.compute)

---@param replayBase sea.ReplayBase
---@param ctx sea.ComputeContext
function GameplayChart:computeLoaded(replayBase, ctx)
	local mode = NativeMode.get(ctx.chart, ctx.chartmeta)
	if mode == "sdvx" then
		SdvxPreparation.compute(ctx, replayBase)
		return
	end
	if mode == "taiko" then
		TaikoPreparation.compute(ctx, replayBase)
		return
	end
	if mode == "catch" then
		CatchPreparation.compute(ctx, replayBase)
		return
	end
	if mode == "osu" then
		AimPreparation.compute(ctx, replayBase)
		return
	end
	local keys = Settings.keys.gameplay

	ctx:applyModifierReorder(replayBase)

	ctx:computeBase(replayBase)

	ctx:applyTempo(
		self.settings:getChoice(keys.tempo_factor),
		self.settings:getNumber(keys.primary_tempo)
	)
	if self.settings:getBoolean(keys.auto_key_sound) then
		ctx:applyAutoKeysound()
	end
	if self.settings:getBoolean(keys.swap_velocity_type) then
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
---@return sea.ReplayBase
local function getReplayBaseData(replay_base)
	local data = ReplayBase()
	replay_base:exportReplayBase(data)
	return data
end

---@param replayBase sea.ReplayBase
---@param data string
---@param context table?
---@return rizu.GameplayChartComputeResult
function GameplayChart:computeAsync(replayBase, data, context)
	local keys = Settings.keys.gameplay
	local gameplay_config = {
		tempoFactor = self.settings:getChoice(keys.tempo_factor),
		primaryTempo = self.settings:getNumber(keys.primary_tempo),
		autoKeySound = self.settings:getBoolean(keys.auto_key_sound),
		swapVelocityType = self.settings:getBoolean(keys.swap_velocity_type),
	}

	---@type rizu.GameplayChartComputeResult|{error: string}
	local result = compute_async(
		self:getChartviewData(),
		data,
		context,
		getReplayBaseData(replayBase),
		gameplay_config
	)
	assert(not result.error, result.error)
	return result
end

---@param replayBase sea.ReplayBase
---@param ctx sea.ComputeContext
---@param result rizu.GameplayChartComputeResult
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
