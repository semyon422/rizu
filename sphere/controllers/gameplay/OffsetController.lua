local class = require("class")
local math_util = require("math_util")
local ChartmetaUserData = require("sea.chart.ChartmetaUserData")

---@class sphere.OffsetController
---@operator call: sphere.OffsetController
local OffsetController = class()

---@param library rizu.library.Library
---@param computeContext sea.ComputeContext
---@param offsetModel sphere.OffsetModel
---@param rhythm_engine rizu.RhythmEngine
function OffsetController:new(
	library,
	computeContext,
	offsetModel,
	rhythm_engine
)
	self.library = library
	self.computeContext = computeContext
	self.offsetModel = offsetModel
	self.rhythm_engine = rhythm_engine
end

function OffsetController:updateOffsets()
	local chartmeta = assert(self.computeContext.chartmeta)
	local input_offset, visual_offset = self.offsetModel:getInputVisual(chartmeta.hash, chartmeta.index)

	self.rhythm_engine:setInputOffset(input_offset)
	self.rhythm_engine:setVisualOffset(visual_offset)
end

---@param delta number
function OffsetController:increaseLocalOffset(delta)
	local chartsRepo = self.library.chartsRepo
	local chartmeta = assert(self.computeContext.chartmeta)

	local chartmeta_user_data = chartsRepo:getUserChartmetaUserData(chartmeta.hash, chartmeta.index, 1)
	if not chartmeta_user_data then
		chartmeta_user_data = ChartmetaUserData()
		chartmeta_user_data.user_id = 1
		chartmeta_user_data.hash = chartmeta.hash
		chartmeta_user_data.index = chartmeta.index
		chartmeta_user_data = chartsRepo:createChartmetaUserData(chartmeta_user_data)
	end

	chartmeta_user_data.local_offset = math_util.round((chartmeta_user_data.local_offset or 0) + delta, delta)
	chartsRepo:updateChartmetaUserData(chartmeta_user_data)

	self:updateOffsets()
end

function OffsetController:resetLocalOffset()
	local chartsRepo = self.library.chartsRepo
	local chartmeta = assert(self.computeContext.chartmeta)

	local chartmeta_user_data = chartsRepo:getUserChartmetaUserData(chartmeta.hash, chartmeta.index, 1)
	if not chartmeta_user_data then
		return
	end

	chartmeta_user_data.local_offset = nil
	chartsRepo:updateChartmetaUserDataFull(chartmeta_user_data)

	self:updateOffsets()
end

return OffsetController
