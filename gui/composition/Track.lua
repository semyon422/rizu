local Node = require("gui.composition.Node")

---@class gui.Composition.Track: gui.Composition.Node
---@operator call: gui.Composition.Track
---@field gap number
---@field space (number | "*" | "-")[]
---@field direction "column" | "row"
---@field align number
local Track = Node + {}

---@param item gui.View | gui.Composition.Node
---@return number
local getWidth = function(item)
	return item.width
end

---@param item gui.View | gui.Composition.Node
---@return number
local getHeight = function(item)
	return item.height
end

---@param item gui.View | gui.Composition.Node
---@return number
---@return number
local getWidthHeight = function(item)
	return item.width, item.height
end

---@param item gui.View | gui.Composition.Node
---@return number
---@return number
local getHeightWidth = function(item)
	return item.height, item.width
end

---@param item gui.View | gui.Composition.Node
---@param w number
---@param h number
local setWidthHeight = function(item, w, h)
	if item._is_view then
		item.box.width = w
		item.box.height = h
	elseif item._is_node then
		item.width = w
		item.height = h
	end
end

---@param item gui.View | gui.Composition.Node
---@param w number
---@param h number
local setHeightWidth = function(item, h, w)
	if item._is_view then
		item.box.width = w
		item.box.height = h
	elseif item._is_node then
		item.width = w
		item.height = h
	end
end

---@return number
---@return number
local noSwap = function(w, h)
	return w, h
end

---@return number
---@return number
local swap = function(h, w)
	return w, h
end

function Track:applyParams(t)
	self.space = t.space or {}
	self.direction = t.direction or "row"
	self.gap = t.gap or 0
	self.align = t.align or 0

	local diff = #self.views + #self.nodes - #self.space

	if diff then
		for i = 1, diff do
			table.insert(self.space, "-")
		end
	end

	if self.direction == "column" then
		self.getMainSize = getHeight
		self.getCrossSize = getWidth
		self.getSize = getHeightWidth
		self.setSize = setHeightWidth
		self.swapIfNeeded = swap
	else
		self.getMainSize = getWidth
		self.getCrossSize = getHeight
		self.getSize = getWidthHeight
		self.setSize = setWidthHeight
		self.swapIfNeeded = noSwap
	end
end

function Track:measure()
	for _, v in ipairs(self.nodes) do
		v:measure()
	end
end

function Track:grow(available_w, available_h)
	self.width = available_w
	self.height = available_h

	local space_left = self.getMainSize(self) - ((#self.space - 1) * self.gap)
	local cross_size = self.getCrossSize(self)
	local stars_count = 0

	for i, v in ipairs(self.space) do
		local item = self.combined[i]

		if v == "-" then
			local s = self.getMainSize(item)
			self.setSize(item, s, cross_size)
			space_left = space_left - s
		elseif type(v) == "number" then
			if v >= 0 then
				space_left = space_left - v
				if item._is_view then
					self.setSize(item, v, cross_size)
				else ---@cast item gui.Composition.Node
					item:grow(self.swapIfNeeded(v, cross_size))
				end
			else
				local size = (self.getMainSize(self) * -v)
				if item._is_view then
					self.setSize(item, size, cross_size)
				else ---@cast item gui.Composition.Node
					item:grow(self.swapIfNeeded(size, cross_size))
				end
				space_left = space_left - size
			end
		elseif v == "*" then
			stars_count = stars_count + 1
		end
	end

	for i, v in ipairs(self.space) do
		local item = self.combined[i]
		local s = space_left / stars_count

		if v == "*" then
			if item._is_view then
				self.setSize(item, s, cross_size)
			else ---@cast item gui.Composition.Node
				item:grow(self.swapIfNeeded(s, cross_size))
			end
		end
	end
end

function Track:arrange()
	local x = self.x + self.layout_x
	local y = self.y + self.layout_y

	if self.direction == "row" then
		for _, v in ipairs(self.combined) do
			if v._is_view then
				v.box.x = x
				v.box.y = y
				x = x + v.box.width + self.gap
			elseif v._is_node then ---@cast v gui.Composition.Node
				v.layout_x = x
				v.layout_y = y
				x = x + v.width + self.gap
				v:arrange()
			end
		end
	else
		for _, v in ipairs(self.combined) do
			if v._is_view then
				v.box.x = x + (self.width - v.width) * self.align
				v.box.y = y
				y = y + v.box.height + self.gap
			elseif v._is_node then ---@cast v gui.Composition.Node
				v.layout_x = x
				v.layout_y = y + (self.height - v.height) * self.align
				y = y + v.height + self.gap
				v:arrange()
			end
		end
	end
end

return Track
