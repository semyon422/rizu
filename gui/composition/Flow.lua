local Node = require("gui.composition.Node")

---@class gui.Composition.Flow: gui.Composition.Node
---@operator call: gui.Composition.Flow
---@field direction "row" | "column"
---@field gap number
---@field align number
---@field padding [number, number, number, number]
local Flow = Node + {}

function Flow:applyParams(t)
	self.direction = t.direction or "row"
	self.gap = t.gap or 0
	self.align = t.align or 0

	local padding = t.padding
	if type(padding) == "number" then
		self.padding = {padding, padding, padding, padding}
	elseif type(padding) == "table" then
		self.padding = padding
	else
		self.padding = {0, 0, 0, 0}
	end
end

---@param item gui.View | gui.Composition.Node
---@param is_row boolean
---@return number main_size
---@return number cross_size
local function intrinsicSizes(item, is_row)
	if is_row then
		return item.width or 0, item.height or 0
	end
	return item.height or 0, item.width or 0
end

---@param item gui.View | gui.Composition.Node
---@param is_row boolean
---@return number main_size
---@return number cross_size
local function grownSizes(item, is_row)
	if item._is_view then ---@cast item gui.View
		if is_row then
			return item.box.width, item.box.height
		end
		return item.box.height, item.box.width
	end
	---@cast item gui.Composition.Node
	if is_row then
		return item.width, item.height
	end
	return item.height, item.width
end

function Flow:measure()
	for _, v in ipairs(self.nodes) do
		v:measure()
	end

	local pl, pt, pb, pr = self.padding[Node.LEFT], self.padding[Node.UP], self.padding[Node.DOWN], self.padding[Node.RIGHT]
	local is_row = self.direction == "row"
	local num_items = #self.combined
	local main = math.max(0, num_items - 1) * self.gap
	local cross = 0

	for _, v in ipairs(self.combined) do
		local ms, cs = intrinsicSizes(v, is_row)
		main = main + ms
		cross = math.max(cross, cs)
	end

	if is_row then
		self.width, self.height = main + pl + pr, cross + pt + pb
	else
		self.width, self.height = cross + pl + pr, main + pt + pb
	end
end

function Flow:grow()
	for _, item in ipairs(self.combined) do
		local w = item.width or 0
		local h = item.height or 0

		if item._is_view then ---@cast item gui.View
			item.box.width = w
			item.box.height = h
		else ---@cast item gui.Composition.Node
			item:grow(w, h)
		end
	end
end

function Flow:arrange()
	local pl, pt, pb, pr = self.padding[Node.LEFT], self.padding[Node.UP], self.padding[Node.DOWN], self.padding[Node.RIGHT]
	local inner_x = self.x + self.layout_x + pl
	local inner_y = self.y + self.layout_y + pt

	local is_row = self.direction == "row"
	local cross_size = is_row and math.max(0, self.height - pt - pb) or math.max(0, self.width - pl - pr)

	local items = self.combined
	if #items == 0 then return end

	local current_main = is_row and inner_x or inner_y

	for _, item in ipairs(items) do
		local ms, cs = grownSizes(item, is_row)

		local item_x, item_y
		if is_row then
			item_x = current_main
			item_y = inner_y + (cross_size - cs) * self.align
		else
			item_y = current_main
			item_x = inner_x + (cross_size - cs) * self.align
		end

		if item._is_view then ---@cast item gui.View
			item.box.x = item_x
			item.box.y = item_y
		else ---@cast item gui.Composition.Node
			item.layout_x = item_x
			item.layout_y = item_y
			item:arrange()
		end

		current_main = current_main + ms + self.gap
	end
end

return Flow
