local class = require("class")
local table_util = require("table_util")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local DiffcalcRegistry = require("chart.difficulty.DiffcalcRegistry")
local DiffcalcContext = require("chart.difficulty.DiffcalcContext")

local EnpsDiffcalc = require("chart.difficulty.EnpsDiffcalc")
local NotesDiffcalc = require("chart.difficulty.NotesDiffcalc")
local OsuDiffcalc = require("chart.difficulty.OsuDiffcalc")
local MsdDiffcalc = require("chart.difficulty.MsdDiffcalc")
local PreviewDiffcalc = require("chart.difficulty.PreviewDiffcalc")

---@class chart.DifficultyModel
---@operator call: chart.DifficultyModel
local DifficultyModel = class()

function DifficultyModel:new()
	self.registry = DiffcalcRegistry()
	self.context = DiffcalcContext()
	self.registry:add(NotesDiffcalc())
	self.registry:add(EnpsDiffcalc())
	self.registry:add(OsuDiffcalc())
	self.registry:add(MsdDiffcalc())
	self.registry:add(PreviewDiffcalc())
end

---@param chartdiff sea.Chartdiff
---@param chart chart.Chart
---@param rate number
---@return chart.DiffcalcContext
function DifficultyModel:compute(chartdiff, chart, rate)
	assert(AbsoluteLayer * chart.layers.main)
	local context = self.context
	table_util.clear(context)
	context:new(chartdiff, chart, rate)
	self.registry:compute(context, false)
	assert(AbsoluteLayer * chart.layers.main)
	return context
end

return DifficultyModel
