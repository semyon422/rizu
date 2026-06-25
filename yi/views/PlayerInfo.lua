local View = require("gui.View")
local Colors = require("yi.Colors")
local Resources = require("yi.Resources")
local Painter = require("yi.Painter")

---@class yi.views.PlayerInfo : gui.View
---@operator call: yi.views.PlayerInfo
local PlayerInfo = View + {}

local AVATAR_SIZE = 50
local LABEL_X = 58

---@param username string
---@param rank number
---@return string
local function formatUpperLabel(username, rank)
	return ("#%i %s"):format(rank, username)
end

---@param pp number
---@param accuracy number
---@return string
local function formatLowerLabel(pp, accuracy)
	return ("%0.02f ENPS • %0.02f%%"):format(pp, accuracy)
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

	love.graphics.setColor(0.2, 0.2, 0.4, 1)
	love.graphics.draw(Resources.atlas, Resources.quads.pixel, 0, 0, 0, AVATAR_SIZE, AVATAR_SIZE)

	love.graphics.setColor(Colors.text)
	love.graphics.setFont(self.font24)
	love.graphics.print(self.upper_label, LABEL_X, 2)

	love.graphics.setColor(Colors.text_muted)
	love.graphics.setFont(self.font16)
	love.graphics.print(self.lower_label, LABEL_X, 30)
end

return PlayerInfo
