local class = require("class")

---@class gui.Composition.Node
---@operator call: gui.Composition.Node
---@field parent gui.Composition.Node?
---@field x number offset within parent (set via params)
---@field y number offset within parent (set via params)
---@field layout_x number assigned by parent during arrange
---@field layout_y number assigned by parent during arrange
---@field width number measured or grown size
---@field height number measured or grown size
---@field views gui.View[]
---@field nodes gui.Composition.Node[]
---@field combined gui.View[] | gui.Composition.Node[]
local Node = class()

Node.LEFT = 1
Node.UP = 2
Node.DOWN = 3
Node.RIGHT = 4
Node._is_node = true

---@param t ({[string]: any} | gui.View[] | gui.Composition.Node[])?
function Node:new(t)
	t = t or {}
	self.x = 0
	self.y = 0
	self.layout_x = 0
	self.layout_y = 0
	self.width = 0
	self.height = 0
	self.views = {}
	self.nodes = {}
	self.combined = {}

	for _, v in ipairs(t) do
		if v._is_view then
			table.insert(self.views, v)
		elseif v._is_node then
			v.parent = self
			table.insert(self.nodes, v)
		end

		table.insert(self.combined, v)
	end

	self:applyParams(t)
end

---@param t {[string]: any}
function Node:applyParams(t) end

---Compute intrinsic size bottom-up. Default implementation recurses into child nodes only.
function Node:measure()
	for _, v in ipairs(self.nodes) do
		v:measure()
	end
end

---Distribute available space top-down, setting self.width/self.height and sizing children.
---@param available_w number
---@param available_h number
function Node:grow(available_w, available_h)
	error("Not implemented")
end

---Assign final positions to children using self.x + self.layout_x as origin.
function Node:arrange()
	error("Not implemented")
end

---@param t gui.View[]
function Node:insertViewsInto(t)
	for _, v in ipairs(self.combined) do
		if v._is_view then ---@cast v gui.View
			table.insert(t, v)
		elseif v._is_node then ---@cast v gui.Composition.Node
			v:insertViewsInto(t)
		end
	end
end

return Node
