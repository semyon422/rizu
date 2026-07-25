local View = require("gui.View")
local ArrangeStrategy = require("gui.layout.ArrangeStrategy")

---@class gui.layout.StackContainer.Config
---@field padding? gui.layout.Padding
---@field align_items_x? gui.layout.Align
---@field align_items_y? gui.layout.Align
---@field layout_transition? gui.layout.LayoutTransition

---Places every child in the same padded inner rect. Non-fill alignment uses the
---child's authored size on that axis.
---@class gui.layout.StackContainer : gui.View, gui.ArrangeStrategy
---@operator call: gui.layout.StackContainer
---@overload fun(config: gui.layout.StackContainer.Config?): gui.layout.StackContainer
---@field padding gui.layout.Padding
---@field align_items_x gui.layout.Align
---@field align_items_y gui.layout.Align
---@field layout_transition gui.layout.LayoutTransition?
local StackContainer = View + {}

local valid_aligns = {fill = true, start = true, center = true, ["end"] = true}

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

---@param name string
---@param align any
local function validateAlign(name, align)
	assert(valid_aligns[align],
		("%s must be fill|start|center|end (got %s)"):format(name, tostring(align)))
end

---@param name string
---@param align gui.layout.Align|number
---@param position number
---@param available number
---@param desired number
---@return number position
---@return number size
local function placeAxis(name, align, position, available, desired)
	if align == "fill" then
		return position, available
	end
	assert(isFiniteNumber(desired) and desired > 0,
		("%s non-fill alignment requires a finite authored size > 0 (got %s)"):format(name, tostring(desired)))
	if type(align) == "number" then
		return position + (available - desired) * align, desired
	elseif align == "start" then
		return position, desired
	elseif align == "center" then
		return position + (available - desired) / 2, desired
	end
	return position + available - desired, desired
end

---@param config gui.layout.StackContainer.Config?
function StackContainer:new(config)
	View.new(self)
	config = config or {}
	self.padding = config.padding or 0
	self.align_items_x = config.align_items_x or "fill"
	self.align_items_y = config.align_items_y or "fill"
	self.layout_transition = config.layout_transition

	validatePadding(self.padding)
	validateAlign("align_items_x", self.align_items_x)
	validateAlign("align_items_y", self.align_items_y)
	ArrangeStrategy.validateLayoutTransition(self, self.layout_transition)
	self.arrange_strategy = self

	for _, child in ipairs(config) do
		self:add(child)
	end
end

---@return number left
---@return number top
---@return number right
---@return number bottom
function StackContainer:normalizePadding()
	local padding = self.padding
	if type(padding) == "number" then
		return padding, padding, padding, padding
	end
	return padding[1], padding[2], padding[3], padding[4]
end

---@param container gui.View
function StackContainer:arrange(container)
	local left, top, right, bottom = self:normalizePadding()
	local inner_width = math.max(0, container.width - left - right)
	local inner_height = math.max(0, container.height - top - bottom)
	for _, child in ipairs(container.children) do
		if not child.layout_ignore then
			local desired_width = child.offset_max[1] - child.offset_min[1]
			local desired_height = child.offset_max[2] - child.offset_min[2]
			local x, width = placeAxis("align_items_x", child.align_x or self.align_items_x, left, inner_width, desired_width)
			local y, height = placeAxis("align_items_y", child.align_y or self.align_items_y, top, inner_height, desired_height)
			child.arranged = {x, y, width, height}
		end
	end
end

---@return number width
---@return number height
function StackContainer:getContentSize()
	local max_width, max_height = 0, 0
	for _, child in ipairs(self.children) do
		if not child.layout_ignore then
			local width = child.offset_max[1] - child.offset_min[1]
			local height = child.offset_max[2] - child.offset_min[2]
			assert(isFiniteNumber(width) and width >= 0, "child authored width must be finite and non-negative")
			assert(isFiniteNumber(height) and height >= 0, "child authored height must be finite and non-negative")
			max_width = math.max(max_width, width)
			max_height = math.max(max_height, height)
		end
	end
	local left, top, right, bottom = self:normalizePadding()
	return max_width + left + right, max_height + top + bottom
end

---@return gui.layout.StackContainer
function StackContainer:fitContent()
	local width, height = self:getContentSize()
	self:setSize(width, height)
	return self
end

return StackContainer
