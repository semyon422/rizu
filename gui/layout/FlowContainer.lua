local View = require("gui.View")
local ArrangeStrategy = require("gui.layout.ArrangeStrategy")

---@class gui.layout.FlowContainer.Config
---@field direction? "row"|"column"
---@field gap? number
---@field align? number
---@field padding? gui.layout.Padding
---@field layout_transition? gui.layout.LayoutTransition
---@field [number] gui.View

---Packs children at their authored sizes along one axis. Unlike
---TrackContainer, FlowContainer does not distribute available main-axis space.
---@class gui.layout.FlowContainer : gui.View, gui.ArrangeStrategy
---@operator call: gui.layout.FlowContainer
---@overload fun(config: gui.layout.FlowContainer.Config?): gui.layout.FlowContainer
---@field direction "row"|"column"
---@field gap number
---@field align number
---@field padding gui.layout.Padding
---@field layout_transition gui.layout.LayoutTransition?
local FlowContainer = View + {}

local valid_directions = {row = true, column = true}

---@param value any
---@return boolean
local function isFiniteNumber(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

---@param padding gui.layout.Padding
local function validatePadding(padding)
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

---@param config gui.layout.FlowContainer.Config?
function FlowContainer:new(config)
	View.new(self)
	config = config or {}
	self.direction = config.direction or "row"
	self.gap = config.gap or 0
	self.align = config.align or 0
	self.padding = config.padding or 0
	self.layout_transition = config.layout_transition

	assert(valid_directions[self.direction],
		("direction must be row|column (got %s)"):format(tostring(self.direction)))
	assert(isFiniteNumber(self.gap) and self.gap >= 0,
		("gap must be a finite non-negative number (got %s)"):format(tostring(self.gap)))
	assert(isFiniteNumber(self.align) and self.align >= 0 and self.align <= 1,
		("align must be a finite number in [0, 1] (got %s)"):format(tostring(self.align)))
	validatePadding(self.padding)
	ArrangeStrategy.validateLayoutTransition(self, self.layout_transition)

	self.arrange_strategy = self

	for _, child in ipairs(config) do
		self:add(child)
	end
end

---@param direction "row"|"column"
---@return gui.layout.FlowContainer
function FlowContainer:setDirection(direction)
	assert(valid_directions[direction],
		("direction must be row|column (got %s)"):format(tostring(direction)))
	self.direction = direction
	self:invalidate()
	return self
end

---@param gap number
---@return gui.layout.FlowContainer
function FlowContainer:setGap(gap)
	assert(isFiniteNumber(gap) and gap >= 0,
		("gap must be a finite non-negative number (got %s)"):format(tostring(gap)))
	self.gap = gap
	self:invalidate()
	return self
end

---@param padding gui.layout.Padding
---@return gui.layout.FlowContainer
function FlowContainer:setPadding(padding)
	validatePadding(padding)
	self.padding = padding
	self:invalidate()
	return self
end

---@param align number
---@return gui.layout.FlowContainer
function FlowContainer:setAlign(align)
	assert(isFiniteNumber(align) and align >= 0 and align <= 1,
		("align must be a finite number in [0, 1] (got %s)"):format(tostring(align)))
	self.align = align
	self:invalidate()
	return self
end

---@return number left
---@return number top
---@return number right
---@return number bottom
function FlowContainer:normalizePadding()
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
	local width = child.offset_max[1] - child.offset_min[1]
	local height = child.offset_max[2] - child.offset_min[2]
	assert(isFiniteNumber(width) and width >= 0,
		("FlowContainer child authored width must be finite and non-negative (got %s)"):format(tostring(width)))
	assert(isFiniteNumber(height) and height >= 0,
		("FlowContainer child authored height must be finite and non-negative (got %s)"):format(tostring(height)))
	return width, height
end

---@param container gui.View
function FlowContainer:arrange(container)
	local left, top, right, bottom = self:normalizePadding()
	local inner_width = math.max(0, container.width - left - right)
	local inner_height = math.max(0, container.height - top - bottom)
	local is_row = self.direction == "row"
	local position = is_row and left or top
	local arranged_count = 0

	for _, child in ipairs(container.children) do
		if not child.layout_ignore then
			if arranged_count > 0 then
				position = position + self.gap
			end
			local width, height = desiredSize(child)
			if is_row then
				local y = top + (inner_height - height) * self.align
				child.arranged = {position, y, width, height}
				position = position + width
			else
				local x = left + (inner_width - width) * self.align
				child.arranged = {x, position, width, height}
				position = position + height
			end
			arranged_count = arranged_count + 1
		end
	end
end

---@return number width
---@return number height
function FlowContainer:getContentSize()
	local total_main = 0
	local max_cross = 0
	local measured_count = 0
	for _, child in ipairs(self.children) do
		if not child.layout_ignore then
			local width, height = desiredSize(child)
			total_main = total_main + (self.direction == "row" and width or height)
			max_cross = math.max(max_cross, self.direction == "row" and height or width)
			measured_count = measured_count + 1
		end
	end
	total_main = total_main + self.gap * math.max(0, measured_count - 1)
	local left, top, right, bottom = self:normalizePadding()
	if self.direction == "row" then
		return total_main + left + right, max_cross + top + bottom
	end
	return max_cross + left + right, total_main + top + bottom
end

---@param container gui.View
---@return number width
---@return number height
function FlowContainer:contentSize(container)
	assert(container == self, "FlowContainer can only measure itself")
	return self:getContentSize()
end

---Sets the authored size to the packed content size.
---@return gui.layout.FlowContainer
function FlowContainer:fitContent()
	local width, height = self:getContentSize()
	self:setSize(width, height)
	return self
end

return FlowContainer
