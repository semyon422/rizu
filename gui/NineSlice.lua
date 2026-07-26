local View = require("gui.View")
local Painter = require("gui.Painter")
local NineSliceUsage = require("gui.NineSliceUsage")

---@class gui.NineSlice : gui.View
---@operator call: gui.NineSlice
---@field usage gui.NineSliceUsage
---@field color gui.Color
local NineSlice = View + {}

---@param texture love.Texture
---@param quads gui.NineSliceQuads Quads ordered left-to-right, top-to-bottom.
---@param color gui.Color?
function NineSlice:new(texture, quads, color)
	View.new(self)
	self.usage = NineSliceUsage(texture, quads)
	self.color = color or {1, 1, 1, 1}
	self:setSize(self.usage.width, self.usage.height)
end

---@param color gui.Color
function NineSlice:setColor(color)
	self.color = color
end

function NineSlice:draw()
	Painter.setColorTable(self.color)
	self.usage:draw(self.width, self.height)
end

return NineSlice
