local Node = require("gui.composition.Node")

---@class gui.Composition.Anchor: gui.Composition.Node
---@operator call: gui.Composition.Anchor
---@field pivot [number, number]
local Anchor = Node + {}

function Anchor:applyParams(t)
	local pivot = t.pivot
	self.x = t.x or 0
	self.y = t.y or 0

	if type(pivot) == "table" then
		assert(#pivot, "Pivot table should have 2 values")
		self.pivot = pivot
	else
		self.pivot = {0, 0}
	end
end

function Anchor:measure()
	local total_w, total_h = 0, 0

	for _, v in ipairs(self.views) do
		total_w = total_w + v.width
		total_h = total_h + v.height
	end

	---@cast total_w number
	---@cast total_h number

	for _, v in ipairs(self.nodes) do
		v:measure()
		total_w = total_w + v.width
		total_h = total_h + v.height
	end

	self.width, self.height = total_w, total_h
end

function Anchor:grow(available_w, available_h)
	self.available_w = available_w
	self.available_h = available_h

	for _, v in ipairs(self.views) do
		v.box.width = self.width
		v.box.height = self.height
	end

	for _, v in ipairs(self.nodes) do
		v:grow(self.width, self.height)
	end
end

function Anchor:arrange()
	local x = self.x + self.layout_x + (self.available_w - self.width) * self.pivot[1]
	local y = self.y + self.layout_y + (self.available_h - self.height) * self.pivot[2]

	for _, v in ipairs(self.views) do
		v.box.x = x
		v.box.y = y
	end

	for _, v in ipairs(self.nodes) do
		v.layout_x = x
		v.layout_y = y
		v:arrange()
	end
end

return Anchor
