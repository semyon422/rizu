local Node = require("gui.composition.Node")

---@class gui.Composition.Stack: gui.Composition.Node
---@operator call: gui.Composition.Stack
---@field padding [number, number, number, number] left top bottom right
local Stack = Node + {}

function Stack:applyParams(t)
	local padding = t.padding

	if type(padding) == "number" then
		self.padding = {padding, padding, padding, padding}
	elseif type(padding) == "table" then
		assert(#padding == 4, "Padding table should have 4 numbers")
		self.padding = padding
	else
		self.padding = {0, 0, 0, 0}
	end
end

function Stack:grow(available_w, available_h)
	self.width = available_w
	self.height = available_h

	local inner_w = math.max(0, available_w - self.padding[Node.LEFT] - self.padding[Node.RIGHT])
	local inner_h = math.max(0, available_h - self.padding[Node.UP] - self.padding[Node.DOWN])

	for _, v in ipairs(self.combined) do
		if v._is_view then ---@cast v gui.View
			v.box.width = inner_w
			v.box.height = inner_h
		elseif v._is_node then ---@cast v gui.Composition.Node
			v:grow(inner_w, inner_h)
		end
	end
end

function Stack:arrange()
	local x = self.x + self.layout_x + self.padding[Node.LEFT]
	local y = self.y + self.layout_y + self.padding[Node.UP]

	for _, v in ipairs(self.combined) do
		if v._is_view then ---@cast v gui.View
			v.box.x = x
			v.box.y = y
		elseif v._is_node then ---@cast v gui.Composition.Node
			v.layout_x = x
			v.layout_y = y
			v:arrange()
		end
	end
end

return Stack
