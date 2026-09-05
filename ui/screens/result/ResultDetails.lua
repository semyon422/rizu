local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local HitGraph = require("ui.screens.result.HitGraph")

---@class ui.screens.result.ResultDetails.Row
---@field name string
---@field value string

---@class ui.screens.result.ResultDetails : gui.View
---@operator call: ui.screens.result.ResultDetails
---@field rows ui.screens.result.ResultDetails.Row[]
local ResultDetails = View + {}

function ResultDetails:new()
	View.new(self)
	self.font = Resources.getFont("regular", 20)
	self.title_font = Resources.getFont("bold", 32)
	self.rows = {}
	self.hit_graph = self:add(HitGraph()):anchorPercent(0.38, 0.08, 0.97, 0.92)
end

---@param name string
---@param value any
function ResultDetails:addRow(name, value)
	self.rows[#self.rows + 1] = {
		name = name,
		value = value == nil and "<unavailable>" or tostring(value),
	}
end

---@param game sphere.GameController
function ResultDetails:bind(game)
	self.rows = {}
	local score_engine = game.rhythm_engine.score_engine
	local judges = score_engine.judgesSource
	local combo = score_engine.comboSource
	local accuracy = score_engine.accuracySource
	local normalscore = score_engine.scores.normalscore
	self.hit_graph:bind(score_engine)

	if judges then
		local names, counts = judges:getJudgeNames(), judges:getJudges()
		for index, count in ipairs(counts) do
			self:addRow(names[index] or ("Judge %d"):format(index), count)
		end
	end

	self:addRow("Combo", combo and combo:getCombo())
	self:addRow("Max Combo", combo and combo:getMaxCombo())
	self:addRow("Score System Accuracy", accuracy and accuracy:getAccuracyString())
	self:addRow("Normalscore Accuracy", normalscore and normalscore:getAccuracyString())
end

function ResultDetails:draw()
	Painter.setColorTable(Colors.background)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)

	local x = 40
	local y = 40
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.title_font)
	love.graphics.print("RESULT VALUES", x, y)

	y = y + self.title_font:getHeight() + 24
	love.graphics.setFont(self.font)
	for _, row in ipairs(self.rows) do
		Painter.setColorTable(Colors.muted)
		love.graphics.print(row.name, x, y)
		Painter.setColorTable(Colors.text)
		love.graphics.print(row.value, x + 280, y)
		y = y + self.font:getHeight() + 10
	end
end

return ResultDetails
