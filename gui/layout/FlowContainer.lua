local View = require("gui.View")
local Layout = require("gui.layout.Layout")

---@class gui.layout.FlowContainer.Config
---@field direction? "row"|"column"
---@field gap? number
---@field align? number|"baseline" "baseline" (row only) aligns children that define getBaseline() on a shared baseline; others stay at the start.
---@field padding? gui.layout.Padding
---@field layout_transition? gui.layout.LayoutTransition
---@field [number] gui.View

---Packs children at their authored sizes along one axis. Unlike
---TrackContainer, FlowContainer does not distribute available main-axis space.
---@class gui.layout.FlowContainer : gui.View
---@operator call: gui.layout.FlowContainer
---@overload fun(config: gui.layout.FlowContainer.Config?): gui.layout.FlowContainer
---@field direction "row"|"column"
---@field gap number
---@field align number
---@field baseline_align boolean
---@field padding gui.layout.Insets
local FlowContainer = View + {}

local valid_directions = {row = true, column = true}

local isFiniteNumber = Layout.isFiniteNumber

---@param config gui.layout.FlowContainer.Config?
function FlowContainer:new(config)
	View.new(self)
	config = config or {}
	self.direction = config.direction or "row"
	self.gap = config.gap or 0
	local align = config.align
	self.baseline_align = align == "baseline"
	if self.baseline_align or align == nil then
		align = 0
	end
	---@cast align number
	self.align = align
	self.padding = Layout.normalizePadding(config.padding or 0)
	self.layout_transition = config.layout_transition

	assert(valid_directions[self.direction],
		("direction must be row|column (got %s)"):format(tostring(self.direction)))
	assert(isFiniteNumber(self.gap) and self.gap >= 0,
		("gap must be a finite non-negative number (got %s)"):format(tostring(self.gap)))
	assert(isFiniteNumber(self.align) and self.align >= 0 and self.align <= 1,
		("align must be a finite number in [0, 1] (got %s)"):format(tostring(self.align)))
	Layout.validateTransition(self.layout_transition)

	for _, child in ipairs(config) do
		self:add(child)
	end
end

---@param direction "row"|"column"
---@return gui.layout.FlowContainer
function FlowContainer:setDirection(direction)
	assert(valid_directions[direction],
		("direction must be row|column (got %s)"):format(tostring(direction)))
	if self.direction == direction then return self end
	self.direction = direction
	self:invalidate()
	return self
end

---@param gap number
---@return gui.layout.FlowContainer
function FlowContainer:setGap(gap)
	assert(isFiniteNumber(gap) and gap >= 0,
		("gap must be a finite non-negative number (got %s)"):format(tostring(gap)))
	if self.gap == gap then return self end
	self.gap = gap
	self:invalidate()
	return self
end

---@param padding gui.layout.Padding
---@return gui.layout.FlowContainer
function FlowContainer:setPadding(padding)
	local insets = Layout.normalizePadding(padding)
	local old = self.padding
	if old[1] == insets[1] and old[2] == insets[2] and old[3] == insets[3] and old[4] == insets[4] then
		return self
	end
	self.padding = insets
	self:invalidate()
	return self
end

---@param align number|"baseline"
---@return gui.layout.FlowContainer
function FlowContainer:setAlign(align)
	local baseline_align = align == "baseline"
	if baseline_align then
		align = 0
	end
	---@cast align number
	assert(isFiniteNumber(align) and align >= 0 and align <= 1,
		("align must be a finite number in [0, 1] (got %s)"):format(tostring(align)))
	if self.align == align and self.baseline_align == baseline_align then return self end
	self.baseline_align = baseline_align
	self.align = align
	self:invalidate()
	return self
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

---Distance from a child's top to its baseline, if it has one.
---@param child gui.View
---@return number?
local function childBaseline(child)
	local get = child.getBaseline
	return get and get(child) or nil
end

---Largest baseline offset and largest extent below the baseline among baseline children.
---@return number? above
---@return number below
function FlowContainer:measureBaseline()
	local above, below = nil, nil ---@type number?, number?
	for _, child in ipairs(self.children) do
		if not child.layout_ignore then
			local baseline = childBaseline(child)
			if baseline then
				local _, height = desiredSize(child)
				above = math.max(above or baseline, baseline)
				below = math.max(below or 0, height - baseline)
			end
		end
	end
	return above, below or 0
end

---Baseline of this container when it is a baseline-aligned row, measured from its top.
---@return number?
function FlowContainer:getBaseline()
	if self.direction ~= "row" or not self.baseline_align then
		return nil
	end
	local above = self:measureBaseline()
	if not above then
		return nil
	end
	return self.padding[2] + above
end

function FlowContainer:arrange()
	local left, top, right, bottom = unpack(self.padding)
	local inner_width = math.max(0, self.width - left - right)
	local inner_height = math.max(0, self.height - top - bottom)
	local is_row = self.direction == "row"
	local position = is_row and left or top
	local arranged_count = 0
	local above, below = nil, nil ---@type number?, number?
	if is_row and self.baseline_align then
		above, below = self:measureBaseline()
	end

	for _, child in ipairs(self.children) do
		if not child.layout_ignore then
			if arranged_count > 0 then
				position = position + self.gap
			end
			local width, height = desiredSize(child)
			if is_row then
				local baseline = above and childBaseline(child)
				local y ---@type number
				if baseline then
					y = top + above - baseline
				else
					y = top + (inner_height - height) * self.align
				end
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
	local above, below = nil, nil ---@type number?, number?
	if self.direction == "row" and self.baseline_align then
		above, below = self:measureBaseline()
		max_cross = above and above + below or 0
	end
	for _, child in ipairs(self.children) do
		if not child.layout_ignore then
			local width, height = desiredSize(child)
			total_main = total_main + (self.direction == "row" and width or height)
			if not (above and childBaseline(child)) then
				max_cross = math.max(max_cross, self.direction == "row" and height or width)
			end
			measured_count = measured_count + 1
		end
	end
	total_main = total_main + self.gap * math.max(0, measured_count - 1)
	local left, top, right, bottom = unpack(self.padding)
	if self.direction == "row" then
		return total_main + left + right, max_cross + top + bottom
	end
	return max_cross + left + right, total_main + top + bottom
end

---Sets the authored size to the packed content size.
---@return gui.layout.FlowContainer
function FlowContainer:fitContent()
	local width, height = self:getContentSize()
	self:setSize(width, height)
	return self
end

return FlowContainer
