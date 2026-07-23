local ArrangeStrategy = require("gui.layout.ArrangeStrategy")

---@class gui.layout.Flow.Config
---@field direction? ("row"|"column")  default "row"
---@field gap? number  spacing between children on the main axis, ≥ 0
---@field align? number  cross-axis alignment factor in [0, 1], default 0
---@field padding? Padding  {left, top, right, bottom} or single number
---@field layout_transition? gui.layout.LayoutTransition

---Flow places each non-`layout_ignore` child at its authored size in one line.
---`align` positions children within the padded cross axis: 0 is start, 0.5 is
---center, and 1 is end.
---@class gui.layout.Flow: gui.ArrangeStrategy
---@overload fun(config: gui.layout.Flow.Config?): gui.layout.Flow
---@field direction "row"|"column"
---@field gap number
---@field align number
---@field padding Padding
---@field layout_transition gui.layout.LayoutTransition?
local Flow = ArrangeStrategy + {}

local valid_directions = {row = true, column = true}

---@param value any
---@return boolean
local function isFiniteNumber(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

---@param config gui.layout.Flow.Config?
function Flow:new(config)
	config = config or {}
	self.direction = config.direction or "row"
	self.gap = config.gap or 0
	self.align = config.align or 0
	self.padding = config.padding or 0
	self.layout_transition = config.layout_transition
	self:validate()
end

function Flow:validate()
	assert(valid_directions[self.direction],
		("direction must be row|column (got %s)"):format(tostring(self.direction)))
	assert(isFiniteNumber(self.gap) and self.gap >= 0,
		("gap must be a finite non-negative number (got %s)"):format(tostring(self.gap)))
	assert(isFiniteNumber(self.align) and self.align >= 0 and self.align <= 1,
		("align must be a finite number in [0, 1] (got %s)"):format(tostring(self.align)))
	self:validatePadding(self.padding)
	self:validateLayoutTransition(self.layout_transition)
end

---@param padding Padding
function Flow:validatePadding(padding)
	if type(padding) == "number" then
		assert(isFiniteNumber(padding) and padding >= 0,
			("padding must be a finite non-negative number (got %s)"):format(tostring(padding)))
		return
	end
	assert(type(padding) == "table" and #padding == 4,
		"padding table must be {left, top, right, bottom}")
	for i = 1, 4 do
		assert(isFiniteNumber(padding[i]) and padding[i] >= 0,
			("padding[%d] must be a finite non-negative number (got %s)"):format(i, tostring(padding[i])))
	end
end

---@return number left
---@return number top
---@return number right
---@return number bottom
function Flow:normalizePadding()
	local padding = self.padding
	if type(padding) == "number" then
		return padding, padding, padding, padding
	end
	return padding[1], padding[2], padding[3], padding[4]
end

---@param child gui.View
---@return number width
---@return number height
local function desiredSize(child)
	assert(child.anchor_min[1] == 0 and child.anchor_min[2] == 0
		and child.anchor_max[1] == 0 and child.anchor_max[2] == 0,
		"Flow-managed child anchors must use the default point anchor {0,0}->{0,0}")
	local width = child.offset_max[1] - child.offset_min[1]
	local height = child.offset_max[2] - child.offset_min[2]
	assert(isFiniteNumber(width) and width >= 0,
		("Flow child authored width must be finite and non-negative (got %s)"):format(tostring(width)))
	assert(isFiniteNumber(height) and height >= 0,
		("Flow child authored height must be finite and non-negative (got %s)"):format(tostring(height)))
	return width, height
end

---@param container gui.View
function Flow:arrange(container)
	local pl, pt, pr, pb = self:normalizePadding()
	local inner_w = math.max(0, container.width - pl - pr)
	local inner_h = math.max(0, container.height - pt - pb)
	local row = self.direction == "row"
	local position = row and pl or pt

	for _, child in ipairs(container.children) do
		if not child.layout_ignore then
			local width, height = desiredSize(child)
			if row then
				local y = pt + (inner_h - height) * self.align
				child.arranged = {position, y, width, height}
				position = position + width + self.gap
			else
				local x = pl + (inner_w - width) * self.align
				child.arranged = {x, position, width, height}
				position = position + height + self.gap
			end
		end
	end
end

---@param container gui.View
---@return number contentWidth
---@return number contentHeight
function Flow:contentSize(container)
	local row = self.direction == "row"
	local total_main = 0
	local max_cross = 0
	local count = 0
	for _, child in ipairs(container.children) do
		if not child.layout_ignore then
			local width, height = desiredSize(child)
			total_main = total_main + (row and width or height)
			max_cross = math.max(max_cross, row and height or width)
			count = count + 1
		end
	end
	if count > 1 then
		total_main = total_main + self.gap * (count - 1)
	end
	local pl, pt, pr, pb = self:normalizePadding()
	if row then
		return total_main + pl + pr, max_cross + pt + pb
	end
	return max_cross + pl + pr, total_main + pt + pb
end

return Flow
