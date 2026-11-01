local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")

local lg = love.graphics

local HEIGHT = 44
local PADDING = 40 -- the menu's edge, so the title lines up with the music strip
local TITLE_GAP = 16
local LIVE_DOT = 8
local PART_GAP = 10 -- between the parts of a score
local SCORE_SPACING = 32 -- between scores
local SPEED = 60 -- pixels a second

---@alias ui.screens.main_menu_v2.StatusLine.Part {text: string, font: love.Font, color: gui.Color}
---@alias ui.screens.main_menu_v2.StatusLine.Item {parts: ui.screens.main_menu_v2.StatusLine.Part[], width: number}

---The bottom edge of the main menu: the newest scores of all players, scrolling.
---@class ui.screens.main_menu_v2.StatusLine : gui.View
---@operator call: ui.screens.main_menu_v2.StatusLine
---@field ui ui.UserInterface
---@field items ui.screens.main_menu_v2.StatusLine.Item[]
---@field row_width number the scores and their spacing, once
---@field scroll number
---@field unsubscribes fun()[]
local StatusLine = View + {}

StatusLine.HEIGHT = HEIGHT

---@param ui ui.UserInterface
function StatusLine:new(ui)
	View.new(self)
	self.ui = ui
	self.items = {}
	self.row_width = 0
	self.scroll = 0
	self.unsubscribes = {}
	self:setClip(true)
end

function StatusLine:load()
	local online = self.ui.api.online
	local function refresh() self:refresh() end
	self.unsubscribes = {
		online:on("account_changed", refresh),
		online:on("recent_scores_changed", refresh),
	}
	self:refresh()
end

function StatusLine:unload()
	for _, unsubscribe in ipairs(self.unsubscribes) do unsubscribe() end
	self.unsubscribes = {}
end

---Takes the scores again.
function StatusLine:refresh()
	local name_font, chart_font = Resources.getFont("cjk_bold", 15), Resources.getFont("cjk_regular", 14)
	local accuracy_font = Resources.getFont("medium", 15)
	self.items = {}
	self.row_width = 0
	for i, score in ipairs(self.ui.api.online:getRecentScores()) do
		local chart = score.difficulty ~= "" and ("%s [%s]"):format(score.title, score.difficulty) or score.title
		local parts = {
			{text = score.player_name, font = name_font, color = Colors.text},
			{text = ("%.2f%%"):format(score.accuracy * 100), font = accuracy_font, color = Colors.yellow},
			{text = chart, font = chart_font, color = Colors.muted},
		}
		local width = PART_GAP * (#parts - 1) ---@type number
		for _, part in ipairs(parts) do width = width + part.font:getWidth(part.text) end
		self.items[i] = {parts = parts, width = width}
		self.row_width = self.row_width + width + SCORE_SPACING
	end
end

---@param dt number
function StatusLine:update(dt)
	if self.row_width > 0 then
		self.scroll = (self.scroll + SPEED * dt) % self.row_width
	end
end

---@private
---@param item ui.screens.main_menu_v2.StatusLine.Item
---@param x number
function StatusLine:drawItem(item, x)
	for _, part in ipairs(item.parts) do
		Painter.setColorTable(part.color)
		lg.setFont(part.font)
		lg.print(part.text, math.floor(x), math.floor((HEIGHT - part.font:getHeight()) / 2))
		x = x + part.font:getWidth(part.text) + PART_GAP
	end
end

function StatusLine:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.panel)
	lg.rectangle("fill", 0, 0, self.width, self.height)

	local title = self.ui.localization:get("main_menu.recent_scores")
	local title_font = Resources.getFont("medium", 13)
	local title_x = PADDING + LIVE_DOT + 10
	local run_x = title_x + title_font:getWidth(title) + TITLE_GAP * 2

	-- Copies of the row follow each other until the line is full.
	if self.row_width > 0 then
		local x = run_x - self.scroll
		local i = 1
		while x < self.width do
			local item = self.items[i]
			if x + item.width > run_x then self:drawItem(item, x) end
			x = x + item.width + SCORE_SPACING
			i = i % #self.items + 1
		end
	end

	-- The title covers the scores scrolling under it.
	Painter.setColorTable(Colors.panel)
	lg.rectangle("fill", 0, 0, run_x - TITLE_GAP, self.height)
	Painter.setColorTable(Colors.yellow)
	lg.circle("fill", PADDING + LIVE_DOT / 2, HEIGHT / 2, LIVE_DOT / 2, 16)
	Painter.setColorTable(Colors.muted)
	lg.setFont(title_font)
	lg.print(title, title_x, math.floor((HEIGHT - title_font:getHeight()) / 2))
end

return StatusLine
