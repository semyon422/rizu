local Node = require("gui.composition.Node")

---@class gui.Composition.Align: gui.Composition.Node
---@operator call: gui.Composition.Align
---@field direction "row" | "column"
---@field align number 0 to 1
local Align = Node + {}

function Align:applyParams(t)
	self.direction = t.direction or "row"
	self.align = t.align or 0
end

function Align:measure()
	for _, v in ipairs(self.nodes) do
		v:measure()
	end
	local max_w, max_h = 0, 0
	for _, v in ipairs(self.combined) do
		max_w = math.max(max_w, v.width)
		max_h = math.max(max_h, v.height)
	end
	self.width, self.height = max_w, max_h
end

function Align:grow(available_w, available_h)
	self.width = available_w
	self.height = available_h

	for _, v in ipairs(self.combined) do
		if self.direction == "column" then
			if v._is_view then
				v.width = self.width
				v.box.width = self.width
				v.box.height = v.height
			else ---@cast v gui.Composition.Node
				v:grow(self.width, v.height)
			end
		else
			if v._is_view then
				v.height = self.height
				v.box.height = self.height
				v.box.width = v.width
			else ---@cast v gui.Composition.Node
				v:grow(v.width, self.height)
			end
		end
	end
end

function Align:arrange()
	local W, H = self.width, self.height

	for _, v in ipairs(self.combined) do
		local x = self.x + self.layout_x
		local y = self.y + self.layout_y

		if self.direction == "column" then
			y = y + (H - v.height) * self.align
		else
			x = x + (W - v.width) * self.align
		end

		if v._is_view then
			v.box.x = x
			v.box.y = y
		elseif v._is_node then ---@cast v gui.Composition.Node
			v.layout_x = x
			v.layout_y = y
			v:arrange()
		end
	end
end

return Align
