local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.PlayerInfo : gui.View
---@operator call: ui.views.PlayerInfo
---@field font24 love.Font
---@field font16 love.Font
---@field username string
---@field rank integer
---@field performance_points number
---@field accuracy number
---@field upper_label string
---@field lower_label string
local PlayerInfo = View + {}

local AVATAR_SIZE = 50
local LABEL_X = 58

---@param username string
---@param rank integer
---@return string label
local function formatUpperLabel(username, rank)
	return ("#%i %s"):format(rank, username)
end

---@param performance_points number
---@param accuracy number
---@return string label
local function formatLowerLabel(performance_points, accuracy)
	return ("%0.02f ENPS • %0.02f%%"):format(performance_points, accuracy)
end

---@param username string
---@param rank integer
---@param performance_points number
---@param accuracy number
function PlayerInfo:new(username, rank, performance_points, accuracy)
	View.new(self)
	self.font24 = Resources.getFont("regular", 24)
	self.font16 = Resources.getFont("regular", 16)
	self:updateText(username, rank, performance_points, accuracy)
end

---@param username string
---@param rank integer
---@param performance_points number
---@param accuracy number
function PlayerInfo:updateText(username, rank, performance_points, accuracy)
	self.username = username
	self.rank = rank
	self.performance_points = performance_points
	self.accuracy = accuracy
	self.upper_label = formatUpperLabel(username, rank)
	self.lower_label = formatLowerLabel(performance_points, accuracy)
	self:setSize(LABEL_X + self.font24:getWidth(self.upper_label), AVATAR_SIZE)
end

function PlayerInfo:draw()
	Painter.snapToPixel()
	Painter.setColorRgb(0.2, 0.2, 0.4)
	Resources.sprites.pixel:draw(0, 0, 0, AVATAR_SIZE, AVATAR_SIZE)

	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font24)
	love.graphics.print(self.upper_label, LABEL_X, 2)

	Painter.setColorTable(Colors.text_muted)
	love.graphics.setFont(self.font16)
	love.graphics.print(self.lower_label, LABEL_X, 30)
end

return PlayerInfo
