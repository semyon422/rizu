local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local NineSliceUsage = require("gui.NineSliceUsage")
local Resources = require("ui.Resources")
local HeaderButton = require("ui.screens.song_select_v2.HeaderButton")

---Bell with the unread count, circled by a spinner while tasks run.
---@class ui.screens.song_select_v2.NotificationsButton : ui.screens.song_select_v2.HeaderButton
---@operator call: ui.screens.song_select_v2.NotificationsButton
---@field notifications rizu.api.Notifications
---@field badge gui.NineSliceUsage
---@field font love.Font
local NotificationsButton = HeaderButton + {}

local RING_RADIUS = 16
local RING_SPEED = math.pi * 2
local BADGE_HEIGHT = 18

---@param notifications rizu.api.Notifications
---@param on_click fun()
function NotificationsButton:new(notifications, on_click)
	HeaderButton.new(self, Resources.sprites.icon_bell, on_click)
	self.notifications = notifications
	self.badge = NineSliceUsage(Resources.nine_slices.notification_badge)
	self.font = Resources.getFont("medium", 12)
end

function NotificationsButton:draw()
	HeaderButton.draw(self)
	local cx, cy = self.width / 2, self.height / 2

	if self.notifications:getTaskCount() > 0 then
		local start = love.timer.getTime() * RING_SPEED
		Painter.setColorTable(Colors.accent)
		local line_width = love.graphics.getLineWidth()
		love.graphics.setLineWidth(2)
		love.graphics.arc("line", "open", cx, cy, RING_RADIUS, start, start + math.pi / 2, 16)
		love.graphics.setLineWidth(line_width)
	end

	local unread = self.notifications:getUnreadCount()
	if unread == 0 then return end
	local text = tostring(unread)
	local width = math.max(BADGE_HEIGHT, self.font:getWidth(text) + 10)
	local x, y = math.floor(cx + 4), math.floor(cy - 16)
	love.graphics.push()
	love.graphics.translate(x, y)
	Painter.setColorTable(Colors.danger)
	self.badge:draw(width, BADGE_HEIGHT)
	love.graphics.pop()
	Painter.setColorRgb(1, 1, 1)
	love.graphics.setFont(self.font)
	love.graphics.printf(text, x, y + math.floor((BADGE_HEIGHT - self.font:getHeight()) / 2), width, "center")
end

return NotificationsButton
