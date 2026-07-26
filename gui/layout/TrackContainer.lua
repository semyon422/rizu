local View = require("gui.View")
local ArrangeStrategy = require("gui.layout.ArrangeStrategy")

---@alias gui.layout.TrackSize number|"*"|string

---@class gui.layout.TrackContainer.Config
---@field direction? "row"|"column"
---@field gap? number
---@field padding? gui.layout.Padding
---@field layout_transition? gui.layout.LayoutTransition
---@field [number] gui.View

---Divides its main axis into tracks. Children always fill their track on the
---cross axis; alignment and intrinsic sizing are intentionally not supported.
---@class gui.layout.TrackContainer : gui.View, gui.ArrangeStrategy
---@operator call: gui.layout.TrackContainer
---@overload fun(config: gui.layout.TrackContainer.Config?): gui.layout.TrackContainer
---@field direction "row"|"column"
---@field gap number
---@field padding gui.layout.Padding
---@field layout_transition gui.layout.LayoutTransition?
---@field private track_sizes {[gui.View]: gui.layout.TrackSize}
local TrackContainer = View + {}

local valid_directions = {row = true, column = true}

---@param value any
---@return boolean
local function isFiniteNumber(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

---@param size any
---@return boolean
local function isTrackSize(size)
	if isFiniteNumber(size) then
		return size >= 0
	end
	if size == "*" then
		return true
	end
	if type(size) ~= "string" then
		return false
	end
	local percent = size:match("^(%d+%.?%d*)%%$")
	return percent ~= nil
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

---@param config gui.layout.TrackContainer.Config?
function TrackContainer:new(config)
	View.new(self)
	config = config or {}
	self.direction = config.direction or "row"
	self.gap = config.gap or 0
	self.padding = config.padding or 0
	self.layout_transition = config.layout_transition
	---@type {[gui.View]: gui.layout.TrackSize}
	self.track_sizes = {}

	assert(valid_directions[self.direction],
		("direction must be row|column (got %s)"):format(tostring(self.direction)))
	assert(isFiniteNumber(self.gap) and self.gap >= 0,
		("gap must be a finite non-negative number (got %s)"):format(tostring(self.gap)))
	validatePadding(self.padding)
	self:validateLayoutTransition(self.layout_transition)

	-- Reuse View's strategy hook internally. To callers this remains a container.
	self.arrange_strategy = self

	for _, child in ipairs(config) do
		self:add(child)
	end
end

---@param transition gui.layout.LayoutTransition?
function TrackContainer:validateLayoutTransition(transition)
	ArrangeStrategy.validateLayoutTransition(self, transition)
end

---@param direction "row"|"column"
---@return gui.layout.TrackContainer
function TrackContainer:setDirection(direction)
	assert(valid_directions[direction],
		("direction must be row|column (got %s)"):format(tostring(direction)))
	self.direction = direction
	self:invalidate()
	return self
end

---@param gap number
---@return gui.layout.TrackContainer
function TrackContainer:setGap(gap)
	assert(isFiniteNumber(gap) and gap >= 0,
		("gap must be a finite non-negative number (got %s)"):format(tostring(gap)))
	self.gap = gap
	self:invalidate()
	return self
end

---@param padding gui.layout.Padding
---@return gui.layout.TrackContainer
function TrackContainer:setPadding(padding)
	validatePadding(padding)
	self.padding = padding
	self:invalidate()
	return self
end

---@generic T: gui.View
---@param child T
---@param size? gui.layout.TrackSize
---@return T
function TrackContainer:add(child, size)
	size = size or "*"
	assert(isTrackSize(size),
		("track size must be a non-negative number, \"NN%%\", or \"*\" (got %s)"):format(tostring(size)))
	View.add(self, child)
	self.track_sizes[child] = size
	return child
end

---@generic T: gui.View
---@param index integer
---@param child T
---@param size? gui.layout.TrackSize
---@return T
function TrackContainer:insert(index, child, size)
	size = size or self.track_sizes[child] or "*"
	assert(isTrackSize(size),
		("track size must be a non-negative number, \"NN%%\", or \"*\" (got %s)"):format(tostring(size)))
	View.insert(self, index, child)
	self.track_sizes[child] = size
	return child
end

---@param child gui.View
function TrackContainer:remove(child)
	View.remove(self, child)
	self.track_sizes[child] = nil
end

---@param child gui.View
---@param size gui.layout.TrackSize
---@return gui.layout.TrackContainer
function TrackContainer:setTrackSize(child, size)
	assert(child.parent == self, "cannot size a view that is not a child")
	assert(isTrackSize(size),
		("track size must be a non-negative number, \"NN%%\", or \"*\" (got %s)"):format(tostring(size)))
	self.track_sizes[child] = size
	self:invalidate()
	return self
end

---@return number left
---@return number top
---@return number right
---@return number bottom
function TrackContainer:normalizePadding()
	local padding = self.padding
	if type(padding) == "number" then
		return padding, padding, padding, padding
	end
	return padding[1], padding[2], padding[3], padding[4]
end

---@param container gui.View
function TrackContainer:arrange(container)
	local left, top, right, bottom = self:normalizePadding()
	local inner_width = math.max(0, container.width - left - right)
	local inner_height = math.max(0, container.height - top - bottom)
	local is_row = self.direction == "row"
	local main_size = is_row and inner_width or inner_height
	local children = container.children
	local layout_count = 0
	for _, child in ipairs(children) do
		if not child.layout_ignore then
			layout_count = layout_count + 1
		end
	end
	local total_gap = self.gap * math.max(0, layout_count - 1)
	local fixed_size = 0
	local star_count = 0
	---@type number[]
	local resolved_sizes = {}

	for i, child in ipairs(children) do
		if not child.layout_ignore then
			local size = self.track_sizes[child]
			assert(size ~= nil, "TrackContainer child has no track size")
			if size == "*" then
				star_count = star_count + 1
			elseif type(size) == "number" then
				resolved_sizes[i] = size
				fixed_size = fixed_size + size
			else
				local percent = assert(tonumber(size:match("^(%d+%.?%d*)%%$")))
				local resolved = main_size * percent / 100
				resolved_sizes[i] = resolved
				fixed_size = fixed_size + resolved
			end
		end
	end

	local remaining = math.max(0, main_size - fixed_size - total_gap)
	local star_size = star_count > 0 and remaining / star_count or 0
	local position = is_row and left or top
	local arranged_count = 0
	for i, child in ipairs(children) do
		if not child.layout_ignore then
			if arranged_count > 0 then
				position = position + self.gap
			end
			local size = resolved_sizes[i] or star_size
			if is_row then
				child.arranged = {position, top, size, inner_height}
			else
				child.arranged = {left, position, inner_width, size}
			end
			position = position + size
			arranged_count = arranged_count + 1
		end
	end
end

---@param container gui.View
---@return number width
---@return number height
function TrackContainer:contentSize(container)
	local main_size = 0
	local measured_count = 0
	for _, child in ipairs(container.children) do
		if not child.layout_ignore then
			local size = self.track_sizes[child]
			assert(type(size) == "number", "contentSize requires numeric track sizes")
			main_size = main_size + size
			measured_count = measured_count + 1
		end
	end
	main_size = main_size + self.gap * math.max(0, measured_count - 1)
	local left, top, right, bottom = self:normalizePadding()
	if self.direction == "row" then
		return main_size + left + right, top + bottom
	end
	return left + right, main_size + top + bottom
end

return TrackContainer
