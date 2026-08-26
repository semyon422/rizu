local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Panel = require("ui.views.Panel")

---@class ui.views.PlayerInfo : gui.View
---@operator call: ui.views.PlayerInfo
---@field font love.Font
---@field username string
---@field text_y number
local PlayerInfo = View + {}

local HEIGHT = 50
local AVATAR_SIZE = 34
local LEFT_PADDING = 16
local GAP = 10
local RIGHT_PADDING = 12

---@param username string
function PlayerInfo:new(username)
	View.new(self)
	self.font = Resources.getFont("bold", 13)
	self.avatar = self:add(Panel({
		color = Colors.surface_raised,
		line_color = Colors.outline,
	}))
	self:updateText(username)
end

---@param username string
function PlayerInfo:updateText(username)
	self.username = username
	local text_width = self.font:getWidth(username)
	local avatar_x = LEFT_PADDING + text_width + GAP
	self:setSize(avatar_x + AVATAR_SIZE + RIGHT_PADDING, HEIGHT)
	self.avatar:anchorFixed(avatar_x, (HEIGHT - AVATAR_SIZE) / 2, AVATAR_SIZE, AVATAR_SIZE)
end

---@param old_x number
---@param old_y number
---@param old_width number
---@param old_height number
function PlayerInfo:onLayoutChanged(old_x, old_y, old_width, old_height)
	self.text_y = (self.height - self.font:getHeight()) / 2
end

function PlayerInfo:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font)
	love.graphics.print(self.username, LEFT_PADDING, self.text_y)
end

return PlayerInfo
