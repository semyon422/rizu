local View = require("gui.View")
local Painter = require("gui.Painter")
local NineSliceUsage = require("gui.NineSliceUsage")

---@class gui.NineSlice : gui.View
---@operator call: gui.NineSlice
---@field usage gui.NineSliceUsage
---@field color gui.Color
---@field fixed_scale boolean
local NineSlice = View + {}

---@param sprites gui.NineSliceSprites Sprites ordered left-to-right, top-to-bottom.
---@param color gui.Color?
---@param fixed_scale boolean? Keep texture pixels 1:1 under UI scaling.
function NineSlice:new(sprites, color, fixed_scale)
	View.new(self)
	self.usage = NineSliceUsage(sprites)
	self.color = color or {1, 1, 1, 1}
	self.fixed_scale = fixed_scale or false
	self:setSize(self.usage.width, self.usage.height)
end

---@param color gui.Color
function NineSlice:setColor(color)
	self.color = color
end

function NineSlice:draw()
	Painter.setColorTable(self.color)
	if self.fixed_scale then
		self.usage:drawFixedScale(self.width, self.height, assert(self.screen).ui_scale)
	else
		self.usage:draw(self.width, self.height)
	end
end

return NineSlice
