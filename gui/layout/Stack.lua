local ArrangeStrategy = require("gui.layout.ArrangeStrategy")

---Config for a Stack strategy.
---@class gui.layout.Stack.Config
---@field padding? Padding  {left, top, right, bottom} or a single number for all four sides
---@field align_items_x? gui.layout.Align  default "fill"
---@field align_items_y? gui.layout.Align  default "fill"

---Padding/margin tuple: {left, top, right, bottom} or a single number.
---@alias Padding number|{[1]: number, [2]: number, [3]: number, [4]: number}

---Stack: every non-`layout_ignore` child receives the same padded inner rect
---(or its desired size aligned within it on each axis per `align_items_x` /
---`align_items_y`, overridable per child via `align_self`).
---@class gui.layout.Stack: gui.ArrangeStrategy
---@overload fun(config: gui.layout.Stack.Config?): gui.layout.Stack
---@field padding Padding
---@field align_items_x gui.layout.Align
---@field align_items_y gui.layout.Align
local Stack = ArrangeStrategy + {}

---@type {[string]: true}
local valid_aligns = {fill = true, start = true, center = true, ["end"] = true}

---Place a child on one axis. Returns the arranged origin and size.
---@param field_name string  for error messages
---@param align gui.layout.Align
---@param start number  inner origin on this axis
---@param size number   inner size on this axis
---@param desired number  child's authored size on this axis (offset_max - offset_min)
---@return number origin
---@return number size
local function placeAxis(field_name, align, start, size, desired)
	if align == "fill" then
		return start, size
	end
	assert(desired > 0,
		("%s non-fill alignment requires desired size > 0 (got %s)"):format(field_name, desired))
	if align == "start" then
		return start, desired
	elseif align == "center" then
		return start + (size - desired) / 2, desired
	elseif align == "end" then
		return start + size - desired, desired
	end
	error(("%s unknown align %s"):format(field_name, tostring(align)))
end

---@param config gui.layout.Stack.Config?
function Stack:new(config)
	config = config or {}
	self.padding = config.padding or 0
	self.align_items_x = config.align_items_x or "fill"
	self.align_items_y = config.align_items_y or "fill"
	self:validate()
end

function Stack:validate()
	self:validatePadding(self.padding)
	self:validateAlign("align_items_x", self.align_items_x)
	self:validateAlign("align_items_y", self.align_items_y)
end

---@param p number|{[1]: number, [2]: number, [3]: number, [4]: number}
function Stack:validatePadding(p)
	if type(p) == "number" then
		assert(p >= 0, ("padding must be non-negative (got %s)"):format(p))
		return
	end
	assert(type(p) == "table" and #p == 4, "padding table must be {left, top, right, bottom}")
	for i = 1, 4 do
		assert(type(p[i]) == "number" and p[i] >= 0,
			("padding[%d] must be a non-negative number (got %s)"):format(i, tostring(p[i])))
	end
end

---@param name string
---@param value string
function Stack:validateAlign(name, value)
	assert(valid_aligns[value], ("%s must be fill|start|center|end (got %s)"):format(name, tostring(value)))
end

---@param container gui.View
function Stack:arrange(container)
	local pl, pt, pr, pb = self:normalizePadding()
	local inner_x = pl
	local inner_y = pt
	local inner_w = math.max(0, container.width - (pl + pr))
	local inner_h = math.max(0, container.height - (pt + pb))

	for _, child in ipairs(container.children) do
		if not child.layout_ignore then
			local desired_w = child.offset_max[1] - child.offset_min[1]
			local desired_h = child.offset_max[2] - child.offset_min[2]
			local ax = child.align_self or self.align_items_x
			local ay = child.align_self or self.align_items_y
			local x, w = placeAxis("align_items_x", ax, inner_x, inner_w, desired_w)
			local y, h = placeAxis("align_items_y", ay, inner_y, inner_h, desired_h)
			child.arranged = {x, y, w, h}
		end
	end
end

---@return number left
---@return number top
---@return number right
---@return number bottom
function Stack:normalizePadding()
	local p = self.padding
	if type(p) == "number" then
		return p, p, p, p
	end
	return p[1], p[2], p[3], p[4]
end

---@param container gui.View
---@return number contentWidth
---@return number contentHeight
function Stack:contentSize(container)
	local pl, pt, pr, pb = self:normalizePadding()
	local max_w, max_h = 0, 0
	for _, child in ipairs(container.children) do
		if not child.layout_ignore then
			local dw = child.offset_max[1] - child.offset_min[1]
			local dh = child.offset_max[2] - child.offset_min[2]
			if dw > max_w then max_w = dw end
			if dh > max_h then max_h = dh end
		end
	end
	return max_w + pl + pr, max_h + pt + pb
end

return Stack
