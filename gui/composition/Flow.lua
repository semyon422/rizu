local Node = require("gui.composition.Node")

---@class gui.Composition.Flow: gui.Composition.Node
---@operator call: gui.Composition.Flow
---@field gap number
---@field direction "column" | "row"
---@field align number
local Flow = Node + {}

function Flow:applyParams(t)
	self.direction = t.direction or "row"
	self.gap = t.gap or 0
	self.align = t.align or 0
end

---@param item gui.View | gui.Composition.Node
---@return number
---@return number
local function getSize(item)
	return item.width, item.height
end

---@param item gui.View | gui.Composition.Node
---@param width number
---@param height number
local function growItem(item, width, height)
	if item._is_view then
		item.box.width = width
		item.box.height = height
	else ---@cast item gui.Composition.Node
		item:grow(width, height)
	end
end

---@param item gui.View | gui.Composition.Node
---@param x number
---@param y number
local function arrangeItem(item, x, y)
	if item._is_view then
		item.box.x = x
		item.box.y = y
	else ---@cast item gui.Composition.Node
		item.layout_x = x
		item.layout_y = y
		item:arrange()
	end
end

function Flow:measure()
	for _, v in ipairs(self.nodes) do
		v:measure()
	end

	local main_size = math.max(#self.combined - 1, 0) * self.gap
	local cross_size = 0

	if self.direction == "column" then
		for _, v in ipairs(self.combined) do
			local width, height = getSize(v)
			main_size = main_size + height
			cross_size = math.max(cross_size, width)
		end

		self.width, self.height = cross_size, main_size
	else
		for _, v in ipairs(self.combined) do
			local width, height = getSize(v)
			main_size = main_size + width
			cross_size = math.max(cross_size, height)
		end

		self.width, self.height = main_size, cross_size
	end
end

function Flow:grow(_, _)
	for _, v in ipairs(self.combined) do
		growItem(v, v.width, v.height)
	end
end

function Flow:arrange()
	local x = self.x + self.layout_x
	local y = self.y + self.layout_y

	if self.direction == "column" then
		for _, v in ipairs(self.combined) do
			arrangeItem(v, x + (self.width - v.width) * self.align, y)
			y = y + v.height + self.gap
		end
	else
		for _, v in ipairs(self.combined) do
			arrangeItem(v, x, y + (self.height - v.height) * self.align)
			x = x + v.width + self.gap
		end
	end
end

return Flow
