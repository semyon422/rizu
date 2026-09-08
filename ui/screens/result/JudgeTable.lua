local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local ScoreSystemFormatter = require("ui.formatters.ScoreSystemFormatter")

---@class ui.screens.result.JudgeTable.Judge
---@field name string
---@field count integer
---@field color gui.Color

---@class ui.screens.result.JudgeTable : gui.View
---@operator call: ui.screens.result.JudgeTable
---@field font love.Font
---@field judges ui.screens.result.JudgeTable.Judge[]
local JudgeTable = View + {}

function JudgeTable:new()
	View.new(self)
	self.font = Resources.getFont("regular", 20)
	self.judges = {}
end

---@param judges_source rizu.IJudgesSource?
function JudgeTable:bind(judges_source)
	self.judges = {}
	if not judges_source then
		return
	end

	local system = judges_source ---@cast system +rizu.ScoreSystem
	local formatter = ScoreSystemFormatter(system)
	for index, count in ipairs(judges_source:getJudges()) do
		self.judges[#self.judges + 1] = {
			name = formatter:getJudgeName(index),
			count = count,
			color = formatter:getJudgeColor(index),
		}
	end
end

function JudgeTable:draw()
	local row_width = math.min(440, self.width * 0.84)
	local row_height = 38
	local total_judges = 0
	for _, judge in ipairs(self.judges) do
		total_judges = total_judges + judge.count
	end

	love.graphics.setFont(self.font)
	local y = 0
	for _, judge in ipairs(self.judges) do
		local fill_width = total_judges > 0 and row_width * judge.count / total_judges or 0
		if fill_width > 0 then
			Painter.setColorTable(judge.color)
			local gradient = Resources.sprites.result_judge_gradient
			gradient:draw(0, y, 0, fill_width / gradient:getWidth(), (row_height - 2) / gradient:getHeight())
		end
		Painter.setColorTable(judge.color)
		Resources.sprites.pixel:draw(0, y, 0, 4, row_height - 2)
		local count = tostring(judge.count)
		love.graphics.print(count, row_width - self.font:getWidth(count) - 12, y + 7)
		Painter.setColorTable(Colors.text)
		love.graphics.print(judge.name, 14, y + 7)
		y = y + row_height
	end
end

return JudgeTable
