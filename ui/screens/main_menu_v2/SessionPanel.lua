local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")

local lg = love.graphics

local WIDTH, HEIGHT = 520, 179
local PADDING = 18
local HEADER_HEIGHT = 44
local STATS_Y = HEADER_HEIGHT + 14
local ROW_HEIGHT = 57 -- value, label and the gap to the next row
local LIVE_DOT = 8
local DIVIDER_COLOR = {0xF2 / 255, 0xF2 / 255, 1, 0.07}

---Above the menu buttons: this session's time, plays and local #1s, then the best ratings of its passed plays.
---@class ui.screens.main_menu_v2.SessionPanel : gui.View
---@operator call: ui.screens.main_menu_v2.SessionPanel
---@field ui ui.UserInterface
---@field stats rizu.api.Scores.SessionStats
---@field time_text string
local SessionPanel = View + {}

---@param ui ui.UserInterface
function SessionPanel:new(ui)
	View.new(self)
	self.ui = ui
	self.stats = {plays = 0, firsts = 0}
	self.time_text = ""
	self:setSize(WIDTH, HEIGHT)
end

---Asks for the stats again, so plays made since are counted.
function SessionPanel:refresh()
	self.ui.api.scores:getSessionStats(function(stats)
		self.stats = stats or self.stats
	end)
end

---@param dt number
function SessionPanel:update(dt)
	local seconds = os.time() - self.ui.api.scores:getSessionStart()
	self.time_text = ("%d:%02d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

function SessionPanel:draw()
	Painter.snapToPixel()
	local localization = self.ui.localization
	Painter.setColorTable(Colors.panel)
	lg.rectangle("fill", 0, 0, self.width, self.height)

	-- Header: live dot, title, start time.
	local small = Resources.getFont("medium", 13)
	local header_y = math.floor((HEADER_HEIGHT - small:getHeight()) / 2)
	Painter.setColorTable(Colors.success)
	lg.circle("fill", PADDING + LIVE_DOT / 2, HEADER_HEIGHT / 2, LIVE_DOT / 2, 16)
	Painter.setColorTable(Colors.muted)
	lg.setFont(small)
	lg.print(localization:get("main_menu.this_session"), PADDING + LIVE_DOT + 10, header_y)
	local since = localization:get("main_menu.session_since", {
		time = os.date("%H:%M", self.ui.api.scores:getSessionStart()) --[[@as string]],
	})
	lg.print(since, self.width - PADDING - small:getWidth(since), header_y)
	Painter.setColorTable(DIVIDER_COLOR)
	lg.rectangle("fill", 0, HEADER_HEIGHT, self.width, 1)

	-- Stats
	local value_font = Resources.getFont("bold", 24)
	local label_font = Resources.getFont("regular", 13)
	local s = self.stats
	---@param format string
	---@param value number?
	local function best(format, value) return value and format:format(value) or "-" end
	local rows = {
		{
			{self.time_text, "main_menu.session_time"},
			{tostring(s.plays), "main_menu.session_plays"},
			{tostring(s.firsts), "main_menu.session_firsts"},
		},
		{
			{best("%.0f", s.best_pp), "main_menu.session_best_pp"},
			{best("%.2f", s.best_rating), "main_menu.session_best_enps"},
		},
	}
	local inner = self.width - PADDING * 2
	for r, row in ipairs(rows) do
		local y = STATS_Y + (r - 1) * ROW_HEIGHT
		for i, stat in ipairs(row) do
			local x = PADDING + math.floor((i - 1) * inner / #row)
			Painter.setColorTable(Colors.text)
			lg.setFont(value_font)
			lg.print(stat[1], x, y)
			Painter.setColorTable(Colors.muted)
			lg.setFont(label_font)
			lg.print(localization:get(stat[2]), x, y + value_font:getHeight())
		end
	end
end

return SessionPanel
