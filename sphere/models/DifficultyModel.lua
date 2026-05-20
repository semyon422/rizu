local class = require("class")
local table_util = require("table_util")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local DiffcalcRegistry = require("sphere.models.DifficultyModel.DiffcalcRegistry")
local DiffcalcContext = require("sphere.models.DifficultyModel.DiffcalcContext")

local EnpsDiffcalc = require("sphere.models.DifficultyModel.EnpsDiffcalc")
local NotesDiffcalc = require("sphere.models.DifficultyModel.NotesDiffcalc")
local OsuDiffcalc = require("sphere.models.DifficultyModel.OsuDiffcalc")
local MsdDiffcalc = require("sphere.models.DifficultyModel.MsdDiffcalc")
local PreviewDiffcalc = require("sphere.models.DifficultyModel.PreviewDiffcalc")

---@class sphere.DifficultyModel
---@operator call: sphere.DifficultyModel
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
---@param chart ncdk2.Chart
---@param rate number
---@return sphere.DiffcalcContext
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
