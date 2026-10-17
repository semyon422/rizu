local FlowContainer = require("gui.layout.FlowContainer")
local JudgeLine = require("ui.screens.result_v2.JudgeLine")
local JudgeCounts = require("ui.screens.result_v2.JudgeCounts")

---@class ui.screens.result_v2.ResultJudges : gui.layout.FlowContainer
---@operator call: ui.screens.result_v2.ResultJudges
---@field line ui.screens.result_v2.JudgeLine
---@field counts ui.screens.result_v2.JudgeCounts
local ResultJudges = FlowContainer + {}

local WIDTH = 840

function ResultJudges:new()
	FlowContainer.new(self, {direction = "column", gap = 14})
	self.line = self:add(JudgeLine())
	self.line:setWidth(WIDTH)
	self.counts = self:add(JudgeCounts())
	self.counts:setWidth(WIDTH)
	self:fitContent()
end

---@param counts integer[]
---@param ssf ui.formatters.ScoreSystemFormatter
function ResultJudges:bind(counts, ssf)
	local items = {} ---@type ui.screens.result_v2.JudgeCounts.Item[]
	for index, count in ipairs(counts) do
		items[index] = {
			name = ssf:getJudgeName(index),
			count = count,
			color = ssf:getJudgeColor(index),
		}
	end
	self.line:setSegments(items)
	self.counts:setItems(items)
end

return ResultJudges
