local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.PlayerInfo : gui.View
---@operator call: ui.views.PlayerInfo
---@field font16_medium love.Font
---@field font16 love.Font
---@field username string
---@field text_y number
local PlayerInfo = View + {}

local AVATAR_SIZE = 40
local LABEL_X = 48

---@param username string
function PlayerInfo:new(username)
	View.new(self)
	self.font16_medium = Resources.getFont("medium", 16)
	self:updateText(username)
end

---@param username string
function PlayerInfo:updateText(username)
	self.username = username
	self:setSize(LABEL_X + self.font16_medium:getWidth(username), AVATAR_SIZE)
end

---@param old_x number
---@param old_y number
---@param old_width number
---@param old_height number
function PlayerInfo:onLayoutChanged(old_x, old_y, old_width, old_height)
	self.text_y = (self.height - self.font16_medium:getHeight()) / 2
end

function PlayerInfo:draw()
	Painter.snapToPixel()
	Painter.setColorRgb(0.2, 0.2, 0.4)
	Resources.sprites.pixel:draw(self.width - AVATAR_SIZE, 0, 0, AVATAR_SIZE, AVATAR_SIZE)

	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font16_medium)
	love.graphics.print(self.username, 0, self.text_y)
end

return PlayerInfo
