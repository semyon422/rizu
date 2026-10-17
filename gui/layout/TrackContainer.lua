local View = require("gui.View")
local Layout = require("gui.layout.Layout")

---@alias gui.layout.TrackSize number|"*"|string

---@class gui.layout.TrackContainer.Config
---@field direction? "row"|"column"
---@field gap? number
---@field padding? gui.layout.Padding
---@field layout_transition? gui.layout.LayoutTransition
---@field [number] gui.View

---Divides its main axis into tracks. Children always fill their track on the
---cross axis; alignment and intrinsic sizing are intentionally not supported.
---@class gui.layout.TrackContainer : gui.View
---@operator call: gui.layout.TrackContainer
---@overload fun(config: gui.layout.TrackContainer.Config?): gui.layout.TrackContainer
---@field direction "row"|"column"
---@field gap number
---@field padding gui.layout.Insets
---@field private track_sizes {[gui.View]: gui.layout.TrackSize}
---@field private track_percents {[gui.View]: number} Parsed "NN%" track sizes
local TrackContainer = View + {}

local valid_directions = {row = true, column = true}

local isFiniteNumber = Layout.isFiniteNumber

---Validates a track size; returns the percentage for "NN%" sizes.
---@param size any
---@return number? percent
local function parseTrackSize(size)
	if size == "*" or isFiniteNumber(size) and size >= 0 then
		return nil
	end
	local percent = type(size) == "string" and tonumber(size:match("^(%d+%.?%d*)%%$"))
	assert(percent,
		("track size must be a non-negative number, \"NN%%\", or \"*\" (got %s)"):format(tostring(size)))
	return percent
end

---@param config gui.layout.TrackContainer.Config?
function TrackContainer:new(config)
	View.new(self)
	config = config or {}
	self.direction = config.direction or "row"
	self.gap = config.gap or 0
	self.padding = Layout.normalizePadding(config.padding or 0)
	self.layout_transition = config.layout_transition
	---@type {[gui.View]: gui.layout.TrackSize}
	self.track_sizes = {}
	---@type {[gui.View]: number}
	self.track_percents = {}

	assert(valid_directions[self.direction],
		("direction must be row|column (got %s)"):format(tostring(self.direction)))
	assert(isFiniteNumber(self.gap) and self.gap >= 0,
		("gap must be a finite non-negative number (got %s)"):format(tostring(self.gap)))
	Layout.validateTransition(self.layout_transition)

	for _, child in ipairs(config) do
		self:add(child)
	end
end

---@param direction "row"|"column"
---@return gui.layout.TrackContainer
function TrackContainer:setDirection(direction)
	assert(valid_directions[direction],
		("direction must be row|column (got %s)"):format(tostring(direction)))
	if self.direction == direction then return self end
	self.direction = direction
	self:invalidate()
	return self
end

---@param gap number
---@return gui.layout.TrackContainer
function TrackContainer:setGap(gap)
	assert(isFiniteNumber(gap) and gap >= 0,
		("gap must be a finite non-negative number (got %s)"):format(tostring(gap)))
	if self.gap == gap then return self end
	self.gap = gap
	self:invalidate()
	return self
end

---@param padding gui.layout.Padding
---@return gui.layout.TrackContainer
function TrackContainer:setPadding(padding)
	local insets = Layout.normalizePadding(padding)
	local old = self.padding
	if old[1] == insets[1] and old[2] == insets[2] and old[3] == insets[3] and old[4] == insets[4] then
		return self
	end
	self.padding = insets
	self:invalidate()
	return self
end

---@generic T: gui.View
---@param child T
---@param size? gui.layout.TrackSize
---@return T
function TrackContainer:add(child, size)
	size = size or "*"
	local percent = parseTrackSize(size)
	View.add(self, child)
	self.track_sizes[child] = size
	self.track_percents[child] = percent
	return child
end

---@generic T: gui.View
---@param index integer
---@param child T
---@param size? gui.layout.TrackSize
---@return T
function TrackContainer:insert(index, child, size)
	size = size or self.track_sizes[child] or "*"
	local percent = parseTrackSize(size)
	View.insert(self, index, child)
	self.track_sizes[child] = size
	self.track_percents[child] = percent
	return child
end

---@param child gui.View
function TrackContainer:remove(child)
	View.remove(self, child)
	self.track_sizes[child] = nil
	self.track_percents[child] = nil
end

---@param child gui.View
---@param size gui.layout.TrackSize
---@return gui.layout.TrackContainer
function TrackContainer:setTrackSize(child, size)
	assert(child.parent == self, "cannot size a view that is not a child")
	local percent = parseTrackSize(size)
	if self.track_sizes[child] == size then return self end
	self.track_sizes[child] = size
	self.track_percents[child] = percent
	self:invalidate()
	return self
end

function TrackContainer:arrange()
	local left, top, right, bottom = unpack(self.padding)
	local inner_width = math.max(0, self.width - left - right)
	local inner_height = math.max(0, self.height - top - bottom)
	local is_row = self.direction == "row"
	local main_size = is_row and inner_width or inner_height
	local children = self.children
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
				local resolved = main_size * self.track_percents[child] / 100
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

return TrackContainer
