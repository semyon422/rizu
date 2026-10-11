local View = require("gui.View")
local Layout = require("gui.layout.Layout")

---@class gui.layout.StackContainer.Config
---@field padding? gui.layout.Padding
---@field align_items_x? gui.layout.Align
---@field align_items_y? gui.layout.Align
---@field layout_transition? gui.layout.LayoutTransition

---Places every child in the same padded inner rect. Non-fill alignment uses the
---child's authored size on that axis.
---@class gui.layout.StackContainer : gui.View
---@operator call: gui.layout.StackContainer
---@overload fun(config: gui.layout.StackContainer.Config?): gui.layout.StackContainer
---@field padding gui.layout.Insets
---@field align_items_x gui.layout.Align
---@field align_items_y gui.layout.Align
local StackContainer = View + {}

local valid_aligns = {fill = true, start = true, center = true, ["end"] = true}

local isFiniteNumber = Layout.isFiniteNumber

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
	assert(isFiniteNumber(desired) and desired >= 0,
		("%s non-fill alignment requires a finite non-negative authored size (got %s)"):format(name, tostring(desired)))
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
	self.padding = Layout.normalizePadding(config.padding or 0)
	self.align_items_x = config.align_items_x or "fill"
	self.align_items_y = config.align_items_y or "fill"
	self.layout_transition = config.layout_transition

	validateAlign("align_items_x", self.align_items_x)
	validateAlign("align_items_y", self.align_items_y)
	Layout.validateTransition(self.layout_transition)

	for _, child in ipairs(config) do
		self:add(child)
	end
end

---@param padding gui.layout.Padding
---@return gui.layout.StackContainer
function StackContainer:setPadding(padding)
	local insets = Layout.normalizePadding(padding)
	local old = self.padding
	if old[1] == insets[1] and old[2] == insets[2] and old[3] == insets[3] and old[4] == insets[4] then
		return self
	end
	self.padding = insets
	self:invalidate()
	return self
end

function StackContainer:arrange()
	local left, top, right, bottom = unpack(self.padding)
	local inner_width = math.max(0, self.width - left - right)
	local inner_height = math.max(0, self.height - top - bottom)
	for _, child in ipairs(self.children) do
		if not child.layout_ignore then
			local desired_width, desired_height = child:getAuthoredSize()
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
			local width, height = child:getAuthoredSize()
			assert(isFiniteNumber(width) and width >= 0, "child authored width must be finite and non-negative")
			assert(isFiniteNumber(height) and height >= 0, "child authored height must be finite and non-negative")
			max_width = math.max(max_width, width)
			max_height = math.max(max_height, height)
		end
	end
	local left, top, right, bottom = unpack(self.padding)
	return max_width + left + right, max_height + top + bottom
end

---@return gui.layout.StackContainer
function StackContainer:fitContent()
	local width, height = self:getContentSize()
	self:setSize(width, height)
	return self
end

return StackContainer
