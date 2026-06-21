local Node = require("gui.composition.Node")

---@class gui.Composition.Fixed: gui.Composition.Node
---@operator call: gui.Composition.Fixed
local Fixed = Node + {}

function Fixed:applyParams(t)
	self.width = t.width or 0
	self.height = t.height or 0
end

function Fixed:measure()
	for _, v in ipairs(self.nodes) do
		v:measure()
	end
end

function Fixed:grow(_, _)
	for _, v in ipairs(self.views) do
		v.box.width = self.width
		v.box.height = self.height
	end

	for _, v in ipairs(self.nodes) do
		v:grow(self.width, self.height)
	end
end

function Fixed:arrange()
	local x = self.x + self.layout_x
	local y = self.y + self.layout_y

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

return Fixed
