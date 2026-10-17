local FlowContainer = require("gui.layout.FlowContainer")
local Label = require("ui.views.Label")
local Colors = require("ui.Colors")

---@class ui.screens.result_v2.ValueCells.Value
---@field value string
---@field color gui.Color?
---@field suffix string? Smaller muted text after the value, e.g. " / 7491" or " ms".

---A row of value-over-caption cells. The captions are fixed; the values are bound later.
---@class ui.screens.result_v2.ValueCells : gui.layout.FlowContainer
---@operator call: ui.screens.result_v2.ValueCells
---@field values ui.views.Label[]
---@field suffixes ui.views.Label[]
local ValueCells = FlowContainer + {}

---@param captions string[]
---@param gap number?
function ValueCells:new(captions, gap)
	FlowContainer.new(self, {direction = "row", gap = gap or 56})
	self:setCaptions(captions)
end

---Replaces all cells, for rows whose set of cells depends on the data.
---@param captions string[]
function ValueCells:setCaptions(captions)
	self:clear()
	self.values = {}
	self.suffixes = {}
	for i, caption in ipairs(captions) do
		local cell = self:add(FlowContainer({direction = "column", gap = 2}))
		local top = cell:add(FlowContainer({direction = "row", align = "baseline"}))
		self.values[i] = top:add(Label({
			font_name = "medium",
			font_size = 34,
			color = Colors.text,
			text = "0",
		}))
		self.suffixes[i] = top:add(Label({
			font_name = "medium",
			font_size = 24,
			color = Colors.muted,
			text = "",
		}))
		top:fitContent()
		cell:add(Label({
			font_name = "medium",
			font_size = 13,
			color = Colors.muted,
			text = caption,
		}))
		cell:fitContent()
	end
	self:fitContent()
end

---@param values ui.screens.result_v2.ValueCells.Value[]
function ValueCells:setValues(values)
	for i, label in ipairs(self.values) do
		local item = assert(values[i], "missing value for cell")
		label:setText(item.value)
		label.color = item.color or Colors.text
		self.suffixes[i]:setText(item.suffix or "")
	end
	for _, cell in ipairs(self.children) do
		---@cast cell gui.layout.FlowContainer
		for _, row in ipairs(cell.children) do
			if FlowContainer * row then
				---@cast row gui.layout.FlowContainer
				row:fitContent()
			end
		end
		cell:fitContent()
	end
	self:fitContent()
end

return ValueCells
