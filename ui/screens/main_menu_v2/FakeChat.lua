local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")

local lg = love.graphics

-- shortcut: static messages from the mockup, not wired to anything; replace with a real chat view when chat exists.

local CYAN, ORANGE = Colors.cyan, Colors.orange
local MESSAGE_COLOR = {0xC9 / 255, 0xCF / 255, 0xE0 / 255, 1}
local WELL_COLOR = {0x17 / 255, 0x14 / 255, 0x1E / 255, 1}
local PLACEHOLDER_COLOR = {0x7E / 255, 0x87 / 255, 0x9C / 255, 1}
local DIVIDER_COLOR = {0xF2 / 255, 0xF2 / 255, 1, 0.06}

---{name, name color, text}, oldest first.
---@type {[1]: string, [2]: gui.Color, [3]: string}[]
local MESSAGES = {
	{"Dev", ORANGE, "This is a fake chat and it doesn't work."},
}

local TABS = {"#general", "#mania"}
local TABS_HEIGHT = 44
local TAB_PADDING = 14
local MESSAGES_PADDING_X, MESSAGES_PADDING_Y = 20, 10
local LINE_HEIGHT = 1.6
local INPUT_HEIGHT, INPUT_MARGIN = 44, 10

---A chat panel that only looks like one, for the main menu mockup. The online count is real.
---@class ui.screens.main_menu_v2.FakeChat : gui.View
---@operator call: ui.screens.main_menu_v2.FakeChat
---@field ui ui.UserInterface
---@field tab_font love.Font
---@field status_font love.Font
---@field font love.Font
---@field input_font love.Font
local FakeChat = View + {}

---@param ui ui.UserInterface
function FakeChat:new(ui)
	View.new(self)
	self.ui = ui
	self.tab_font = Resources.getFont("medium", 15)
	self.status_font = Resources.getFont("regular", 14)
	self.font = Resources.getFont("regular", 16)
	self.input_font = Resources.getFont("regular", 15)
end

---@param color gui.Color
---@param x number
---@param y number
---@param w number
---@param h number
local function rect(color, x, y, w, h)
	Painter.setColorTable(color)
	Resources.sprites.pixel:draw(x, y, 0, w, h)
end

function FakeChat:drawTabs()
	local x = 10
	local text_y = math.floor(8 + (TABS_HEIGHT - 8 - self.tab_font:getHeight()) / 2)
	lg.setFont(self.tab_font)
	for i, tab in ipairs(TABS) do
		local width = self.tab_font:getWidth(tab) + TAB_PADDING * 2
		Painter.setColorTable(i == 1 and Colors.text or Colors.muted)
		lg.print(tab, x + TAB_PADDING, text_y)
		if i == 1 then
			rect(CYAN, x, TABS_HEIGHT - 2, width, 2)
		end
		x = x + width + 2
	end
	rect(DIVIDER_COLOR, 0, TABS_HEIGHT, self.width, 1)

	local count = self.ui.api.online:getOnlineCount()
	local localization = self.ui.localization
	local status = count and localization:get("song_select.online", {count = count}) or localization:get("song_select.offline")
	local status_x = math.floor(self.width - 18 - self.status_font:getWidth(status))
	local status_y = math.floor(8 + (TABS_HEIGHT - 8 - self.status_font:getHeight()) / 2)
	lg.setFont(self.status_font)
	Painter.setColorTable(Colors.muted)
	lg.print(status, status_x, status_y)
end

---Newest at the bottom; older lines stop at the tabs.
function FakeChat:drawMessages()
	local font = self.font
	local width = self.width - MESSAGES_PADDING_X * 2
	local line_height = font:getHeight() * LINE_HEIGHT
	local top = TABS_HEIGHT + MESSAGES_PADDING_Y
	local y = self.height - INPUT_HEIGHT - INPUT_MARGIN - MESSAGES_PADDING_Y
	lg.setFont(font)
	Painter.setColorRgb(1, 1, 1)
	for i = #MESSAGES, 1, -1 do
		local name, name_color, text = MESSAGES[i][1], MESSAGES[i][2], MESSAGES[i][3]
		local line = {name_color, name .. ": ", MESSAGE_COLOR, text}
		local _, lines = font:getWrap(name .. ": " .. text, width)
		y = y - #lines * line_height
		if y < top then break end
		lg.printf(line, MESSAGES_PADDING_X, math.floor(y + (line_height - font:getHeight()) / 2), width)
	end
end

function FakeChat:drawInput()
	local x, y = INPUT_MARGIN, self.height - INPUT_HEIGHT - INPUT_MARGIN
	local width = self.width - INPUT_MARGIN * 2
	rect(WELL_COLOR, x, y, width, INPUT_HEIGHT)
	lg.setFont(self.input_font)
	Painter.setColorTable(PLACEHOLDER_COLOR)
	lg.print("Say something…", x + 14, math.floor(y + (INPUT_HEIGHT - self.input_font:getHeight()) / 2))
	local icon = Resources.sprites.icon_send
	local size = 18
	local scale = size / icon:getWidth()
	Painter.setColorTable(Colors.muted)
	icon:draw(x + width - 14 - size, y + (INPUT_HEIGHT - size) / 2, 0, scale, scale)
end

function FakeChat:draw()
	Painter.snapToPixel()
	rect(Colors.panel, 0, 0, self.width, self.height)
	self:drawTabs()
	self:drawMessages()
	self:drawInput()
end

return FakeChat
