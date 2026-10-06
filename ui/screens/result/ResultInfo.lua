local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")

---@class ui.screens.result.ResultInfo.Item
---@field label string
---@field value string
---@field color gui.Color

---@class ui.screens.result.ResultInfo : gui.View
---@operator call: ui.screens.result.ResultInfo
---@field label_font love.Font
---@field value_font love.Font
---@field items ui.screens.result.ResultInfo.Item[]
local ResultInfo = View + {}

function ResultInfo:new()
	View.new(self)
	self.label_font = Resources.getFont("bold", 12)
	self.value_font = Resources.getFont("regular", 22)
	self.items = {}
end

---@param cvf ui.formatters.ChartviewFormatter
---@param cdf ui.formatters.ChartdiffFormatter
function ResultInfo:bind(cvf, cdf)
	local tempo = cvf:getTempo()
	local difficulty = cdf:getDifficulty()
	local ln = cvf:getLongNoteRatio()

	self.items = {
		{label = "BPM", value = ("%s (%s-%s)"):format(tempo.avg, tempo.min, tempo.max), color = Colors.text},
		{label = "DURATION", value = cvf:getDuration(), color = Colors.text},
		{label = "NOTES", value = cvf:getNoteCount(), color = Colors.text},
		{label = "INPUT MODE", value = cvf:getMode(), color = Colors.text},
		{label = "DIFFICULTY", value = difficulty.value, color = difficulty.color},
		{label = "LN%", value = ln.value, color = ln.color},
	}
end

function ResultInfo:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.background)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)

	local item_count = #self.items
	if item_count == 0 then return end

	local item_width = self.width / item_count
	local label_y = 8
	local value_y = 28

	for i, item in ipairs(self.items) do
		local x = (i - 1) * item_width

		Painter.setColorTable(Colors.muted)
		love.graphics.setFont(self.label_font)
		love.graphics.printf(item.label, x, label_y, item_width, "center")

		Painter.setColorTable(item.color)
		love.graphics.setFont(self.value_font)
		love.graphics.printf(item.value, x, value_y, item_width, "center")
	end
end

return ResultInfo
