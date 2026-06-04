local class = require("class")

---@class gui.Composition
---@operator call: gui.Composition
---@field root gui.Composition.Node
local Composition = class()

---@param width number
---@param height number
function Composition:setDimensions(width, height)
	self.width = width
	self.height = height
end

---@param node gui.Composition.Node
function Composition:setRoot(node)
	self.root = node
end

function Composition:update()
	assert(self.root, "Composition needs root node")
	assert(self.width and self.height, "Composition needs dimensions to be set")
	self.root:measure()
	self.root:grow(self.width, self.height)
	self.root:arrange()
end

---@return gui.View[]
function Composition:getViews()
	local t = {}
	self.root:insertViewsInto(t)
	return t
end

return Composition
