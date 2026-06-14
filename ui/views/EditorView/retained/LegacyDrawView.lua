local View = require("gui.View")

---@alias ui.EditorRetainedDrawFunc fun(screen: table)

---@class ui.EditorLegacyDrawView: gui.View
---@operator call: ui.EditorLegacyDrawView
---@field screen table
---@field drawFunc ui.EditorRetainedDrawFunc
local LegacyDrawView = View + {}

---@param screen table
---@param drawFunc ui.EditorRetainedDrawFunc
function LegacyDrawView:new(screen, drawFunc)
	View.new(self)
	self.screen = screen
	self.drawFunc = drawFunc
	self:setSize(love.graphics.getDimensions())
end

function LegacyDrawView:load()
	self:setSize(love.graphics.getDimensions())
end

function LegacyDrawView:draw()
	self.drawFunc(self.screen)
end

return LegacyDrawView
