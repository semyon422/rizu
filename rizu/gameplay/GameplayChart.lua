local ModeNotes = require("chart.model.ModeNotes")
local Gamemodes = require("rizu.gameplay.Gamemodes")
local class = require("class")
local delay = require("delay")
local thread = require("thread")
local ChartfileReader = require("rizu.library.ChartfileReader")
local IidxDecodeContext = require("chart.format.iidx.DecodeContext")
local Chartdiff = require("sea.chart.Chartdiff")
local Chartmeta = require("sea.chart.Chartmeta")
local DiffcalcContext = require("chart.difficulty.DiffcalcContext")
local SnapshotRestorer = require("chart.refchart.SnapshotRestorer")
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
---@field snapshot refchart.ChartSnapshot
---@field chartmeta sea.Chartmeta
---@field chartdiff sea.Chartdiff
---@field state sea.ModifiersMetaState
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

---@return rizu.GameplayChartConfig
function GameplayChart:getConfig()
	local keys = Settings.keys.gameplay
	return {
		tempoFactor = self.settings:getChoice(keys.tempo_factor),
		primaryTempo = self.settings:getNumber(keys.primary_tempo),
		autoKeySound = self.settings:getBoolean(keys.auto_key_sound),
		swapVelocityType = self.settings:getBoolean(keys.swap_velocity_type),
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
	local ModeNotesAsync = require("chart.model.ModeNotes")
	local ComputeContext = require("sea.compute.ComputeContext")
	local ChartSnapshotAsync = require("chart.refchart.ChartSnapshot")
	local GamemodesAsync = require("rizu.gameplay.Gamemodes")

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

	local mode = compute_context.chartmeta.mode
	local mode_ok, mode_error = pcall(ModeNotesAsync.validate, compute_context.chart, mode)
	if not mode_ok then return {error = tostring(mode_error)} end
	local gamemode = GamemodesAsync[mode]
	-- Class instances do not survive the trip into this thread.
	local replay_base = gamemode:createReplayBase(replay_base_data)
	local prepared, prepare_error = pcall(gamemode.prepare, gamemode, compute_context, replay_base, gameplay_config)
	if not prepared then return {error = tostring(prepare_error)} end

	return {
		snapshot = ChartSnapshotAsync(assert(compute_context.chart)),
		chartmeta = compute_context.chartmeta,
		chartdiff = compute_context.chartdiff,
		state = compute_context.state,
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
	local mode = ctx.chartmeta.mode
	ModeNotes.validate(ctx.chart, mode)
	local gamemode = Gamemodes[mode]
	gamemode:prepare(ctx, gamemode:getReplayBase(replayBase), self:getConfig())
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

---@param replayBase sea.ReplayBase
---@param data string
---@param context table?
---@return rizu.GameplayChartComputeResult
function GameplayChart:computeAsync(replayBase, data, context)
	local replay_base_data = {}
	replayBase:exportReplayBase(replay_base_data)

	---@type rizu.GameplayChartComputeResult|{error: string}
	local result = compute_async(
		self:getChartviewData(),
		data,
		context,
		replay_base_data,
		self:getConfig()
	)
	assert(not result.error, result.error)
	return result
end

---@param replayBase sea.ReplayBase
---@param ctx sea.ComputeContext
---@param result rizu.GameplayChartComputeResult
---@param chart chart.Chart
local function apply_computed(replayBase, ctx, result, chart)
	ctx.chart = chart
	ctx.chartmeta = setmetatable(result.chartmeta, Chartmeta)
	ctx.chartdiff = setmetatable(result.chartdiff, Chartdiff)
	ctx.state = result.state
	ctx.chartdiff_fast = false

	local diffcalc_context = DiffcalcContext()
	diffcalc_context:new(ctx.chartdiff, ctx.chart, replayBase.rate)
	ctx.diffcalc_context = diffcalc_context

	-- Preparation rewrites the base of its own gamemode only; a base of another one stays as it was.
	if Gamemodes[ctx.chartmeta.mode].ReplayBase * replayBase then
		replayBase.modifiers = result.replay_base.modifiers
		replayBase.columns_order = result.replay_base.columns_order
	end
end

---@param replayBase sea.ReplayBase
---@param ctx sea.ComputeContext
---@param result rizu.GameplayChartComputeResult
function GameplayChart:applyComputed(replayBase, ctx, result)
	local chart = assert(SnapshotRestorer():restore(result.snapshot))
	apply_computed(replayBase, ctx, result, chart)
end

---@param replayBase sea.ReplayBase
---@param ctx sea.ComputeContext
---@param result rizu.GameplayChartComputeResult
---@param is_cancelled fun(): boolean
---@return boolean applied
function GameplayChart:applyComputedAsync(replayBase, ctx, result, is_cancelled)
	local get_time = love.timer.getTime
	local deadline = get_time() + 0.004
	local chart = SnapshotRestorer():restore(result.snapshot, function()
		if is_cancelled() then
			return false
		end
		if get_time() >= deadline then
			delay.sleep(1 / 240)
			deadline = get_time() + 0.004
		end
		return not is_cancelled()
	end)
	if not chart or is_cancelled() then
		return false
	end
	apply_computed(replayBase, ctx, result, chart)
	return true
end

---@return string data
---@return table? context
function GameplayChart:prepareAsync()
	return prepare_async(self:getChartviewData())
end

return GameplayChart
