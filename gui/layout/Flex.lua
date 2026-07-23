local ArrangeStrategy = require("gui.layout.ArrangeStrategy")

---Size spec for one Flex child on the main axis (§5.1).
---* number — pixel size
---* "NN%" — percent of inner main size
---* "content" — child's authored size on the main axis
---* "*" — equal share of remaining space after fixed/percent/content children
---@alias gui.layout.SizeSpec number|string|"content"|"*"

---@class gui.layout.Flex.Config
---@field direction? ("row"|"column")  default "row"
---@field gap? number  spacing between children on the main axis, ≥ 0
---@field padding? Padding  {left, top, right, bottom} or single number
---@field sizes? gui.layout.SizeSpec[]  per-child main-axis size; pads with "*"
---@field align_items? gui.layout.Align  cross-axis align, default "fill"
---@field justify? ("start"|"center"|"end")  default "start"
---@field layout_transition? gui.layout.LayoutTransition

---Flex: lays out children on a main axis (`row` = horizontal, `column` =
---vertical) per `sizes`, cross-axis per `align_items` (§5.1, §5.2).
---@class gui.layout.Flex: gui.ArrangeStrategy
---@overload fun(config: gui.layout.Flex.Config?): gui.layout.Flex
---@field direction ("row"|"column")
---@field gap number
---@field padding Padding
---@field sizes gui.layout.SizeSpec[]
---@field align_items gui.layout.Align
---@field justify ("start"|"center"|"end")
---@field layout_transition gui.layout.LayoutTransition?
local Flex = ArrangeStrategy + {}

local valid_directions = {row = true, column = true}
local valid_aligns = {fill = true, start = true, center = true, ["end"] = true}
local valid_justifies = {start = true, center = true, ["end"] = true}

---Place a child on the cross axis.
---@param align gui.layout.Align
---@param start number
---@param size number
---@param desired number
---@return number origin
---@return number size
local function placeCross(align, start, size, desired)
	if align == "fill" then
		return start, size
	end
	assert(desired > 0,
		("cross-axis non-fill alignment requires desired size > 0 (got %s)"):format(desired))
	if align == "start" then
		return start, desired
	elseif align == "center" then
		return start + (size - desired) / 2, desired
	elseif align == "end" then
		return start + size - desired, desired
	end
	error(("unknown align %s"):format(tostring(align)))
end

---@param config gui.layout.Flex.Config?
function Flex:new(config)
	config = config or {}
	self.direction = config.direction or "row"
	self.gap = config.gap or 0
	self.padding = config.padding or 0
	self.sizes = config.sizes or {}
	self.align_items = config.align_items or "fill"
	self.justify = config.justify or "start"
	self.layout_transition = config.layout_transition
	self:validate()
end

function Flex:validate()
	assert(valid_directions[self.direction],
		("direction must be row|column (got %s)"):format(tostring(self.direction)))
	assert(type(self.gap) == "number" and self.gap >= 0,
		("gap must be non-negative number (got %s)"):format(tostring(self.gap)))
	self:validatePadding(self.padding)
	assert(valid_aligns[self.align_items],
		("align_items must be fill|start|center|end (got %s)"):format(tostring(self.align_items)))
	assert(valid_justifies[self.justify],
		("justify must be start|center|end (got %s)"):format(tostring(self.justify)))
	self:validateLayoutTransition(self.layout_transition)
	for i, spec in ipairs(self.sizes) do
		self:validateSizeSpec(i, spec)
	end
end

---@param p Padding
function Flex:validatePadding(p)
	if type(p) == "number" then
		assert(p >= 0, ("padding must be non-negative (got %s)"):format(p))
		return
	end
	assert(type(p) == "table" and #p == 4, "padding table must be {left, top, right, bottom}")
	for i = 1, 4 do
		assert(type(p[i]) == "number" and p[i] >= 0,
			("padding[%d] must be non-negative number (got %s)"):format(i, tostring(p[i])))
	end
end

---@param i integer
---@param spec gui.layout.SizeSpec
function Flex:validateSizeSpec(i, spec)
	if type(spec) == "number" then
		assert(spec >= 0, ("sizes[%d] must be non-negative number (got %s)"):format(i, spec))
		return
	end
	if type(spec) == "string" then
		if spec == "*" or spec == "content" then
			return
		end
		local pct = spec:match("^(%d+%.?%d*)%%$")
		assert(pct, ("sizes[%d] invalid spec %q (want number, \"NN%%\", \"content\", or \"*\")"):format(i, spec))
		return
	end
	error(("sizes[%d] invalid spec %q (want number, \"NN%%\", \"content\", or \"*\")"):format(i, tostring(spec)))
end

---@return number left
---@return number top
---@return number right
---@return number bottom
function Flex:normalizePadding()
	local p = self.padding
	if type(p) == "number" then
		return p, p, p, p
	end
	return p[1], p[2], p[3], p[4]
end

---@param container gui.View
function Flex:arrange(container)
	local pl, pt, pr, pb = self:normalizePadding()
	local inner_x = pl
	local inner_y = pt
	local inner_w = math.max(0, container.width - (pl + pr))
	local inner_h = math.max(0, container.height - (pt + pb))

	local row = self.direction == "row"
	-- main axis: x for row, y for column. cross axis: the other one.
	local main_start = row and inner_x or inner_y
	local main_size = row and inner_w or inner_h
	local cross_start = row and inner_y or inner_x
	local cross_size = row and inner_h or inner_w

	-- Collect arrangeable children.
	local children = {} ---@type gui.View[]
	for _, child in ipairs(container.children) do
		if not child.layout_ignore then
			children[#children + 1] = child
		end
	end
	local n = #children
	if n == 0 then
		return
	end

	-- Phase 1: compute fixed sizes; count flex children.
	local sizes = self.sizes
	local fixed = {} -- per-child fixed size on main axis (or nil if flex)
	local n_flex = 0
	local total_fixed = 0
	for i = 1, n do
		local spec = sizes[i] or "*"
		if spec == "*" then
			n_flex = n_flex + 1
		else
			local px
			if type(spec) == "number" then
				px = spec
			elseif spec == "content" then
				local child = children[i]
				px = row
					and (child.offset_max[1] - child.offset_min[1])
					or (child.offset_max[2] - child.offset_min[2])
				assert(type(px) == "number" and px == px and px >= 0 and px < math.huge,
					("Flex child authored main-axis size must be finite and non-negative (got %s)"):format(tostring(px)))
			else
				local pct = tonumber(spec:match("^(%d+%.?%d*)%%$"))
				px = (pct / 100) * main_size
			end
			fixed[i] = px
			total_fixed = total_fixed + px
		end
	end

	local total_gap = self.gap * math.max(0, n - 1)
	local remaining = main_size - total_fixed - total_gap
	local flex_size = n_flex > 0 and math.max(0, remaining / n_flex) or 0

	-- Phase 2: compute main-axis positions with justify.
	local leftover = n_flex == 0 and math.max(0, remaining) or 0
	local offset = self:justifyOffset(leftover)
	local pos = main_start + offset
	local main_positions = {}
	local main_sizes_resolved = {}
	for i = 1, n do
		local child_main = fixed[i] or flex_size
		main_positions[i] = pos
		main_sizes_resolved[i] = child_main
		pos = pos + child_main + self.gap
	end

	-- Phase 3: write arranged per child.
	for i = 1, n do
		local child = children[i]
		local desired_cross = row
			and (child.offset_max[2] - child.offset_min[2])
			or (child.offset_max[1] - child.offset_min[1])
		local align = child.align_self or self.align_items
		local cross_origin, cross_dim = placeCross(align, cross_start, cross_size, desired_cross)
		if row then
			child.arranged = {main_positions[i], cross_origin, main_sizes_resolved[i], cross_dim}
		else
			child.arranged = {cross_origin, main_positions[i], cross_dim, main_sizes_resolved[i]}
		end
	end
end

---@param leftover number
---@return number
function Flex:justifyOffset(leftover)
	if leftover <= 0 then
		return 0
	end
	if self.justify == "start" then
		return 0
	elseif self.justify == "center" then
		return leftover / 2
	elseif self.justify == "end" then
		return leftover
	end
	error("unreachable")
end

---@param container gui.View
---@return number contentWidth
---@return number contentHeight
function Flex:contentSize(container)
	local row = self.direction == "row"
	local n = 0
	for _, child in ipairs(container.children) do
		if not child.layout_ignore then
			n = n + 1
		end
	end
	local total_main = 0
	local max_cross = 0
	local first = true
	for i, child in ipairs(container.children) do
		if not child.layout_ignore then
			local spec = self.sizes[i] or "*"
			assert(spec ~= "*",
				("contentSize: sizes[%d] star spec unsupported for measure"):format(i))
			assert(spec == "content" or type(spec) == "number",
				("contentSize: sizes[%d] percent spec unsupported for measure (got %s)"):format(i, tostring(spec)))
			local dw = child.offset_max[1] - child.offset_min[1]
			local dh = child.offset_max[2] - child.offset_min[2]
			local child_main = spec == "content" and (row and dw or dh) or spec
			total_main = total_main + child_main
			local cross = row and dh or dw
			if cross > max_cross then
				max_cross = cross
			end
			if not first then
				total_main = total_main + self.gap
			end
			first = false
		end
	end
	local pl, pt, pr, pb = self:normalizePadding()
	local w, h
	if row then
		w, h = total_main + pl + pr, max_cross + pt + pb
	else
		w, h = max_cross + pl + pr, total_main + pt + pb
	end
	return w, h
end

return Flex
