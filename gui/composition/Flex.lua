local Node = require("gui.composition.Node")

---@class gui.Composition.Flex: gui.Composition.Node
---@operator call: gui.Composition.Flex
---@field direction "row" | "column"
---@field gap number
---@field justify "start" | "end" | "center" | "space-between"
---@field padding [number, number, number, number]
---@field sizes (number | string | "*")[]?
local Flex = Node + {}

function Flex:applyParams(t)
	self.direction = t.direction or "row"
	self.gap = t.gap or 0
	self.justify = t.justify or "start"

	local padding = t.padding
	if type(padding) == "number" then
		self.padding = {padding, padding, padding, padding}
	elseif type(padding) == "table" then
		self.padding = padding
	else
		self.padding = {0, 0, 0, 0}
	end

	self.sizes = t.sizes
end

function Flex:measure()
	for _, v in ipairs(self.nodes) do
		v:measure()
	end
end

function Flex:grow(available_w, available_h)
	self.width = available_w
	self.height = available_h

	local pl, pt, pb, pr = self.padding[Node.LEFT], self.padding[Node.UP], self.padding[Node.DOWN], self.padding[Node.RIGHT]
	local inner_w = math.max(0, available_w - pl - pr)
	local inner_h = math.max(0, available_h - pt - pb)

	local is_row = self.direction == "row"
	local main_size = is_row and inner_w or inner_h
	local cross_size = is_row and inner_h or inner_w

	local items = self.combined
	local num_items = #items

	local sizes = {}
	local total_fixed = 0
	local num_stars = 0

	if self.sizes then
		for i = 1, num_items do
			local s = self.sizes[i] or "*"
			if s == "*" then
				sizes[i] = -1
				num_stars = num_stars + 1
			elseif type(s) == "string" and s:sub(-1) == "%" then
				local pct = tonumber(s:sub(1, -2)) / 100
				local size = main_size * pct
				sizes[i] = size
				total_fixed = total_fixed + size
			elseif type(s) == "number" then
				sizes[i] = s
				total_fixed = total_fixed + s
			else
				sizes[i] = 0
			end
		end
	else
		for i, item in ipairs(items) do
			local s
			if item._is_view then ---@cast item gui.View
				s = is_row and item.width or item.height
			end
			if s and s > 0 then
				sizes[i] = s
				total_fixed = total_fixed + s
			else
				sizes[i] = -1
				num_stars = num_stars + 1
			end
		end
	end

	total_fixed = total_fixed + math.max(0, num_items - 1) * self.gap
	local space_left = math.max(0, main_size - total_fixed)
	local star_size = num_stars > 0 and (space_left / num_stars) or 0

	self._sizes = sizes
	self._star_size = star_size
	self._num_stars = num_stars

	for i, item in ipairs(items) do
		local size = sizes[i]
		if size == -1 then size = star_size end

		local w, h
		if is_row then
			w, h = size, cross_size
		else
			w, h = cross_size, size
		end

		if item._is_view then ---@cast item gui.View
			item.box.width = w
			item.box.height = h
		else ---@cast item gui.Composition.Node
			item:grow(w, h)
		end
	end
end

function Flex:arrange()
	local pl, pt, pb, pr = self.padding[Node.LEFT], self.padding[Node.UP], self.padding[Node.DOWN], self.padding[Node.RIGHT]
	local inner_x = self.x + self.layout_x + pl
	local inner_y = self.y + self.layout_y + pt

	local is_row = self.direction == "row"
	local main_size = is_row and math.max(0, self.width - pl - pr) or math.max(0, self.height - pt - pb)

	local items = self.combined
	local num_items = #items
	if num_items == 0 then return end

	local sizes = self._sizes
	local star_size = self._star_size
	local num_stars = self._num_stars

	local total_main = math.max(0, num_items - 1) * self.gap
	for i = 1, num_items do
		local s = sizes[i]
		if s == -1 then
			total_main = total_main + star_size
		else
			total_main = total_main + s
		end
	end

	local space_left = math.max(0, main_size - total_main)
	local current_main = is_row and inner_x or inner_y
	local current_gap = self.gap

	if num_stars == 0 and space_left > 0 then
		if self.justify == "end" then
			current_main = current_main + space_left
		elseif self.justify == "center" then
			current_main = current_main + space_left / 2
		elseif self.justify == "space-between" and num_items > 1 then
			current_gap = current_gap + space_left / (num_items - 1)
		end
	end

	for i, item in ipairs(items) do
		local size = sizes[i]
		if size == -1 then size = star_size end

		local item_x, item_y
		if is_row then
			item_x = current_main
			item_y = inner_y
		else
			item_y = current_main
			item_x = inner_x
		end

		if item._is_view then ---@cast item gui.View
			item.box.x = item_x
			item.box.y = item_y
		else ---@cast item gui.Composition.Node
			item.layout_x = item_x
			item.layout_y = item_y
			item:arrange()
		end

		current_main = current_main + size + current_gap
	end
end

return Flex
