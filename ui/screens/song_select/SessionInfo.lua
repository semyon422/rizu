local View = require("gui.View")
local NineSliceUsage = require("gui.NineSliceUsage")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Line = require("ui.views.Line")

local lg = love.graphics

---@class ui.screens.song_select.SessionInfo : gui.View
---@operator call: ui.screens.song_select.SessionInfo
---@field date_text string
---@field session_text string
---@field text_timer number
local SessionInfo = View + {}

local HEIGHT = 30
local PADDING = 12
local GAP = 12
local ITEM_PADDING = 12

local panel_color = {Colors.background[1], Colors.background[2], Colors.background[3], 0.22}

---@param font love.Font
---@param template string
---@return number width
local function maxNumericWidth(font, template)
	local widest_digit = "0"
	local widest_width = font:getWidth(widest_digit)
	for digit = 1, 9 do
		local text = tostring(digit)
		local width = font:getWidth(text)
		if width > widest_width then
			widest_digit = text
			widest_width = width
		end
	end
	return font:getWidth(template:gsub("%%d", widest_digit))
end

function SessionInfo:new()
	View.new(self)
	self.date_font = Resources.getFont("regular", 16)
	self.session_font = Resources.getFont("bold", 16)
	self.status_font = Resources.getFont("medium", 16)
	self.date_text = ""
	self.session_text = ""
	self.status_text = "OFFLINE"
	self.text_timer = 0
	self.background = NineSliceUsage(Resources.nine_slices.song_select_session)
	self:updateText()
	self.first_separator = self:add(Line({color = Colors.outline, direction = "vertical"}))
	self.second_separator = self:add(Line({color = Colors.outline, direction = "vertical"}))
	self:updateSize()
end

function SessionInfo:updateSize()
	local date_width = maxNumericWidth(self.date_font, "%d%d/%d%d/%d%d%d%d %d%d:%d%d")
	local session_width = maxNumericWidth(self.session_font, "%d%d:%d%d:%d%d")
	local status_width = self.status_font:getWidth(self.status_text)
	self.date_x = PADDING
	self.first_separator_x = self.date_x + date_width + GAP
	self.session_x = self.first_separator_x + ITEM_PADDING
	self.second_separator_x = self.session_x + session_width + GAP
	self.status_x = self.second_separator_x + ITEM_PADDING
	self:setSize(self.status_x + status_width + PADDING, HEIGHT)

	self.first_separator:anchorFixed(self.first_separator_x, 0, 0, HEIGHT)
	self.second_separator:anchorFixed(self.second_separator_x, 0, 0, HEIGHT)
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
	local elapsed = math.floor(love.timer.getTime())
	local hours = math.floor(elapsed / 3600)
	local minutes = math.floor((elapsed % 3600) / 60)
	local seconds = elapsed % 60
	self.session_text = ("%02d:%02d:%02d"):format(hours, minutes, seconds)

	local date = os.date("*t")
	---@cast date osdate
	self.date_text = ("%02d/%02d/%04d %02d:%02d"):format(
		date.day, date.month, date.year, date.hour, date.min
	)
end

function SessionInfo:draw()
	Painter.snapToPixel()
	Painter.setColorTable(panel_color)
	self.background:drawFixedScale(self.width, self.height, assert(self.screen).ui_scale)

	local date_y = (HEIGHT - self.date_font:getHeight()) / 2
	local session_y = (HEIGHT - self.session_font:getHeight()) / 2
	local status_y = (HEIGHT - self.status_font:getHeight()) / 2

	Painter.setColorTable(Colors.muted)
	lg.setFont(self.date_font)
	lg.print(self.date_text, self.date_x, date_y)

	Painter.setColorTable(Colors.text)
	lg.setFont(self.session_font)
	lg.print(self.session_text, self.session_x, session_y)

	Painter.setColorTable(Colors.muted)
	lg.setFont(self.status_font)
	lg.print(self.status_text, self.status_x, status_y)
end

return SessionInfo
