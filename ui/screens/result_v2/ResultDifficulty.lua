local FlowContainer = require("gui.layout.FlowContainer")
local Label = require("ui.views.Label")
local Colors = require("ui.Colors")

---@class ui.screens.result_v2.ResultDifficulty : gui.layout.FlowContainer
---@operator call: ui.screens.result_v2.ResultDifficulty
---@field header gui.layout.FlowContainer
---@field hero gui.layout.FlowContainer
---@field rate_row gui.layout.FlowContainer
---@field label ui.views.Label
---@field postfix ui.views.Label
---@field difficulty ui.views.Label
---@field rate ui.views.Label
---@field rate_x ui.views.Label
---@field patterns ui.views.Label
local ResultDifficulty = FlowContainer + {}

function ResultDifficulty:new()
	FlowContainer.new(self, {direction = "column", gap = 4})

	self.header = self:add(FlowContainer({direction = "row", gap = 16, align = "baseline"}))
	self.label = self.header:add(Label({
		font_name = "bold",
		font_size = 20,
		color = Colors.muted,
		text = "DIFFICULTY",
	}))
	self.postfix = self.header:add(Label({
		font_name = "medium",
		font_size = 24,
		color = Colors.accent,
		text = "",
	}))
	self.header:fitContent()

	self.hero = self:add(FlowContainer({direction = "row", gap = 28, align = "baseline"}))
	self.difficulty = self.hero:add(Label({
		font_name = "bold",
		font_size = 120,
		text = "0.0",
	}))
	self.rate_row = self.hero:add(FlowContainer({direction = "row", gap = 4, align = "baseline"}))
	self.rate = self.rate_row:add(Label({
		font_name = "bold",
		font_size = 76,
		text = "1.00",
	}))
	self.rate_x = self.rate_row:add(Label({
		font_name = "bold",
		font_size = 50,
		text = "x",
	}))
	self.rate_row:fitContent()
	self.hero:fitContent()

	self.patterns = self:add(Label({
		font_name = "medium",
		font_size = 32,
		color = Colors.muted,
		text = "",
	}))
	self:fitContent()
end

---@param cvf ui.formatters.ChartviewFormatter
---@param cdf ui.formatters.ChartdiffFormatter
function ResultDifficulty:bind(cvf, cdf)
	local difficulty = cdf:getDifficulty()
	self.difficulty:setText(difficulty.value)
	self.difficulty.color = difficulty.color
	self.postfix:setText(cvf:getDifficulty().postfix)

	local rate = cvf:getTimeRate()
	-- The "x" is a separate, smaller label.
	self.rate:setText((rate.value:gsub("x$", "")))
	self.rate.color = rate.color
	self.rate_x.color = rate.color

	-- Only the two strongest patterns are shown.
	local patterns = cvf:getPatterns()
	local names = {} ---@type string[]
	for _, name in ipairs({patterns.top_full, patterns.second_full}) do
		names[#names + 1] = name:sub(1, 1):upper() .. name:sub(2)
	end
	self.patterns:setText(table.concat(names, " · "))
	self.patterns:setVisible(#names > 0)

	self.rate_row:fitContent()
	self.header:fitContent()
	self.hero:fitContent()
	self:fitContent()
end

return ResultDifficulty
