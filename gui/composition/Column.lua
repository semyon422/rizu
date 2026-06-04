local Node = require("gui.composition.Node")

---@class gui.Composition.Column: gui.Composition.Node
---@operator call: gui.Composition.Column
---@field align number
---@field gap number
local Column = Node + {}

function Column:applyParams(t)
	self.align = t.align or 0
	self.gap = t.gap or 0
end

function Column:measure()
	local max_w, total_h = 0, 0

	for _, v in ipairs(self.views) do
		max_w = math.max(max_w, v.width)
		total_h = total_h + v.height + self.gap
	end

	---@cast max_w number
	---@cast total_h number

	for _, v in ipairs(self.nodes) do
		v:measure()
		max_w = math.max(max_w, v.width)
		total_h = total_h + v.height + self.gap
	end

	self.width, self.height = max_w, total_h
end

function Column:grow(_, _)
	for _, v in ipairs(self.nodes) do
		v:grow(self.width, self.height)
	end
end

function Column:arrange()
	local x = self.x + self.layout_x
	local y = self.y + self.layout_y

	for _, v in ipairs(self.combined) do
		local item_x = x + (self.width - v.width) * self.align

		if v._is_node then ---@cast v gui.Composition.Node
			v.layout_x = item_x
			v.layout_y = y
			v:arrange()
		elseif v._is_view then
			v.box.x = item_x
			v.box.y = y
		end
		y = y + v.height + self.gap
	end
end

return Column
