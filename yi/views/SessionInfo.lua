local View = require("gui.View")
local Colors = require("yi.Colors")
local Resources = require("yi.Resources")
local Painter = require("yi.Painter")

---@class yi.views.SessionInfo : gui.View
---@operator call: yi.views.SessionInfo
local SessionInfo = View + {}

---@param use_us_date boolean?
function SessionInfo:new(use_us_date)
	View.new(self)
	self.use_us_date = use_us_date or false
	self.font24 = Resources.getFont("regular", 24)
	self.font16 = Resources.getFont("regular", 16)
	self.session_text = ""
	self.date_text = ""
	self.text_timer = 0
	self:setSize(240, self.font16:getHeight() + self.font24:getHeight())
	self:updateText()
end

function SessionInfo:update(dt)
	self.text_timer = self.text_timer + dt
	if self.text_timer >= 1 then
		self.text_timer = self.text_timer % 1
		self:updateText()
	end
end

function SessionInfo:updateText()
	local elapsed = love.timer.getTime()
	local hours = math.floor(elapsed / 3600)
	local minutes = math.floor((elapsed % 3600) / 60)
	local seconds = math.floor(elapsed % 60)
	self.session_text = ("Session time: %02d:%02d:%02d"):format(hours, minutes, seconds)

	local t = os.date("*t")
	if self.use_us_date then
		self.date_text = ("%d.%02d.%04d %02d:%02d"):format(t.month, t.day, t.year, t.hour, t.min)
	else
		self.date_text = ("%02d.%02d.%04d %02d:%02d"):format(t.day, t.month, t.year, t.hour, t.min)
	end
end

function SessionInfo:draw()
	Painter.snapToPixel()

	love.graphics.setColor(Colors.text)
	love.graphics.setFont(self.font24)
	love.graphics.print(self.session_text, 0, 0)

	love.graphics.setColor(Colors.text_muted)
	love.graphics.setFont(self.font16)
	love.graphics.print(self.date_text, 0, 28)
end

return SessionInfo
