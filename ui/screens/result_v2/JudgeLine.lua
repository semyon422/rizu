local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.screens.result_v2.JudgeLine.Segment
---@field count integer
---@field color gui.Color

---@class ui.screens.result_v2.JudgeLine : gui.View
---@operator call: ui.screens.result_v2.JudgeLine
---@field segments ui.screens.result_v2.JudgeLine.Segment[]
local JudgeLine = View + {}

local HEIGHT = 12
local GAP = 3
local CAP_WIDTH = 12
local MIN_WIDTH = 6
-- Segment width follows count ^ CURVE, so a few misses stay visible next to thousands of marvelouses.
local CURVE = 0.5

function JudgeLine:new()
	View.new(self)
	self.segments = {}
	self:setHeight(HEIGHT)
end

---@param segments ui.screens.result_v2.JudgeLine.Segment[]
function JudgeLine:setSegments(segments)
	self.segments = segments
end

---Pixel widths of the visible segments, in order.
---@param segments ui.screens.result_v2.JudgeLine.Segment[]
---@param total number
---@return number[]
function JudgeLine.getWidths(segments, total)
	local weights = {} ---@type number[]
	local sum = 0
	for i, segment in ipairs(segments) do
		weights[i] = segment.count ^ CURVE
		sum = sum + weights[i]
	end
	local available = total - GAP * math.max(0, #segments - 1)

	-- A segment carrying a cap can't be narrower than the cap itself.
	local mins = {} ---@type number[]
	for i = 1, #segments do
		mins[i] = math.max(MIN_WIDTH, (i == 1 and CAP_WIDTH or 0) + (i == #segments and CAP_WIDTH or 0))
	end

	-- Segments that would be narrower than their minimum are pinned to it; the rest share what remains.
	local widths = {} ---@type number[]
	local pinned = 0
	local free_sum = sum
	for i = 1, #segments do
		if available * weights[i] / sum < mins[i] then
			widths[i] = mins[i]
			pinned = pinned + mins[i]
			free_sum = free_sum - weights[i]
		end
	end
	for i = 1, #segments do
		widths[i] = widths[i] or (available - pinned) * weights[i] / free_sum
	end
	return widths
end

function JudgeLine:draw()
	local visible = {} ---@type ui.screens.result_v2.JudgeLine.Segment[]
	for _, segment in ipairs(self.segments) do
		if segment.count > 0 then
			visible[#visible + 1] = segment
		end
	end
	if #visible == 0 then
		return
	end

	Painter.snapToPixel()
	local sprites = Resources.sprites
	local widths = JudgeLine.getWidths(visible, self.width)
	local x = 0
	for i, segment in ipairs(visible) do
		local width = widths[i]
		local left = i == 1
		local right = i == #visible
		Painter.setColorTable(segment.color)

		local body_x = left and x + CAP_WIDTH or x
		local body_width = width - (left and CAP_WIDTH or 0) - (right and CAP_WIDTH or 0)
		if left then
			sprites.judge_line_cap_left:draw(x, 0)
		end
		sprites.pixel:draw(body_x, 0, 0, body_width, HEIGHT)
		if right then
			sprites.judge_line_cap_right:draw(x + width - CAP_WIDTH, 0)
		end
		x = x + width + GAP
	end
end

return JudgeLine
