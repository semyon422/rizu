local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.views.SessionInfo : gui.View
---@operator call: ui.views.SessionInfo
---@field use_us_date boolean
---@field font16 love.Font
---@field session_text string
---@field date_text string
---@field text_timer number
local SessionInfo = View + {}

---@param use_us_date boolean?
function SessionInfo:new(use_us_date)
	View.new(self)
	self.use_us_date = use_us_date or false
	self.font16 = Resources.getFont("regular", 16)
	self.session_text = ""
	self.date_text = ""
	self.text_timer = 0
	self:setSize(170, self.font16:getHeight() * 2)
	self:updateText()
end

---@param dt number
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
	self.session_text = ("%02d:%02d:%02d"):format(hours, minutes, seconds)

	local date = os.date("*t")
	---@cast date osdate
	if self.use_us_date then
		self.date_text = ("%d.%02d.%04d %02d:%02d"):format(date.month, date.day, date.year, date.hour, date.min)
	else
		self.date_text = ("%02d.%02d.%04d %02d:%02d"):format(date.day, date.month, date.year, date.hour, date.min)
	end
end

function SessionInfo:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.muted)
	love.graphics.setFont(self.font16)
	love.graphics.printf(self.date_text, 0, 0, self.width, "center")

	love.graphics.setFont(self.font16)
	love.graphics.printf(self.session_text, 0, self.font16:getHeight(), self.width, "center")
end

return SessionInfo
