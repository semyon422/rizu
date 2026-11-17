local class = require("class")
local table_util = require("table_util")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local DiffcalcRegistry = require("chart.difficulty.DiffcalcRegistry")
local DiffcalcContext = require("chart.difficulty.DiffcalcContext")

local EnpsDiffcalc = require("chart.difficulty.EnpsDiffcalc")
local NotesDiffcalc = require("chart.difficulty.NotesDiffcalc")
local OsuDiffcalc = require("chart.difficulty.OsuDiffcalc")
local PatternDiffcalc = require("chart.difficulty.PatternDiffcalc")
local PreviewDiffcalc = require("chart.difficulty.PreviewDiffcalc")
local RizuDiffcalc = require("chart.difficulty.RizuDiffcalc")

---@class chart.DifficultyModel
---@operator call: chart.DifficultyModel
local DifficultyModel = class()

-- Bump when any diffcalc changes, so the library recomputes every chartdiff at startup.
DifficultyModel.version = 1

function DifficultyModel:new()
	self.registry = DiffcalcRegistry()
	self.context = DiffcalcContext()
	self.registry:add(NotesDiffcalc())
	self.registry:add(EnpsDiffcalc())
	self.registry:add(OsuDiffcalc())
	self.registry:add(RizuDiffcalc())
	self.registry:add(PatternDiffcalc())
	self.registry:add(PreviewDiffcalc())
end

---@param chartdiff sea.Chartdiff
---@param chart chart.Chart
---@param rate number
---@param force boolean? recompute every field, even the ones already set
---@return chart.DiffcalcContext
function DifficultyModel:compute(chartdiff, chart, rate, force)
	assert(AbsoluteLayer * chart.layers.main)
	local context = self.context
	table_util.clear(context)
	context:new(chartdiff, chart, rate)
	self.registry:compute(context, not not force)
	assert(AbsoluteLayer * chart.layers.main)
	return context
end

return DifficultyModel
