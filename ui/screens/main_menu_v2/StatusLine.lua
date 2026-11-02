local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local AvatarShader = require("ui.views.AvatarShader")

local lg = love.graphics

local HEIGHT = 44
local TITLE_MARGIN = 24 -- on both sides of the title, inside the area that covers the scrolling scores
local TITLE_GAP = 16
local LIVE_DOT = 8
local PART_GAP = 10 -- between the parts of an item
local SCORE_SPACING = 32 -- between items
local SPEED = 60 -- pixels a second
local AVATAR_SIZE = 22
local AVATAR_RADIUS = 4

---@alias ui.screens.main_menu_v2.StatusLine.Part {text: string?, font: love.Font?, color: gui.Color?, avatar_url: string?} text or avatar
---@alias ui.screens.main_menu_v2.StatusLine.Item {parts: ui.screens.main_menu_v2.StatusLine.Part[], width: number, once: boolean?}

---@param parts ui.screens.main_menu_v2.StatusLine.Part[]
---@param once boolean?
---@return ui.screens.main_menu_v2.StatusLine.Item
local function newItem(parts, once)
	local width = PART_GAP * (#parts - 1) ---@type number
	for _, part in ipairs(parts) do
		width = width + (part.font and part.font:getWidth(part.text) or AVATAR_SIZE)
	end
	---@type ui.screens.main_menu_v2.StatusLine.Item
	local item = {parts = parts, width = width, once = once}
	return item
end

---The bottom edge of the main menu: the newest scores of all players, scrolling, and players coming online
---passing by once.
---@class ui.screens.main_menu_v2.StatusLine : gui.View
---@operator call: ui.screens.main_menu_v2.StatusLine
---@field ui ui.UserInterface
---@field items ui.screens.main_menu_v2.StatusLine.Item[] in the order they pass, the first one leftmost
---@field offset number where the first item starts, from where the items start, 0 and less
---@field unsubscribes fun()[]
---@field avatar_shader love.Shader?
local StatusLine = View + {}

StatusLine.HEIGHT = HEIGHT

---@param ui ui.UserInterface
function StatusLine:new(ui)
	View.new(self)
	self.ui = ui
	self.items = {}
	self.offset = 0
	self.unsubscribes = {}
	self:setClip(true)
end

function StatusLine:load()
	local online = self.ui.api.online
	local function refresh() self:refresh() end
	self.unsubscribes = {
		online:on("account_changed", refresh),
		online:on("recent_scores_changed", refresh),
		online:on("player_joined", function(player) self:addJoin(player) end),
	}
	self:refresh()
end

function StatusLine:unload()
	for _, unsubscribe in ipairs(self.unsubscribes) do unsubscribe() end
	self.unsubscribes = {}
end

---Takes the scores again. Players coming online still pass by.
function StatusLine:refresh()
	local name_font, chart_font = Resources.getFont("cjk_bold", 15), Resources.getFont("cjk_regular", 14)
	local accuracy_font = name_font
	local items = {} ---@type ui.screens.main_menu_v2.StatusLine.Item[]
	for _, item in ipairs(self.items) do
		if item.once then table.insert(items, item) end
	end
	for _, score in ipairs(self.ui.api.online:getRecentScores()) do
		local chart = score.difficulty ~= "" and ("%s [%s]"):format(score.title, score.difficulty) or score.title
		table.insert(items, newItem({
			{text = score.player_name, font = name_font, color = Colors.text},
			{text = ("%.2f%%"):format(score.accuracy * 100), font = accuracy_font, color = Colors.yellow},
			{text = chart, font = chart_font, color = Colors.muted},
		}))
	end
	self.items = items
end

---@return number x where the items start, after the title
function StatusLine:getItemsX()
	local font = Resources.getFont("cjk_bold", 15)
	return TITLE_MARGIN + LIVE_DOT + 10 + font:getWidth(self.ui.localization:get("main_menu.recent_scores")) + TITLE_MARGIN + TITLE_GAP
end

---Puts a player coming online right after the items on screen, so it shows up next.
---@param player rizu.api.Online.Player
function StatusLine:addJoin(player)
	local text = self.ui.localization:get("main_menu.player_joined")
	local item = newItem({
		{avatar_url = player.avatar_url or ""},
		{text = player.name, font = Resources.getFont("cjk_bold", 15), color = Colors.success},
		{text = text, font = Resources.getFont("cjk_regular", 14), color = Colors.success},
	}, true)
	local x = self:getItemsX() + self.offset
	for i, other in ipairs(self.items) do
		if x >= self.width then
			table.insert(self.items, i, item)
			return
		end
		x = x + other.width + SCORE_SPACING
	end
	table.insert(self.items, item)
end

---@param dt number
function StatusLine:update(dt)
	local items = self.items
	if #items == 0 then
		self.offset = 0
		return
	end
	self.offset = self.offset - SPEED * dt
	-- An item gone past the left goes to the end, unless it passes once.
	while items[1] and self.offset + items[1].width + SCORE_SPACING <= 0 do
		local item = table.remove(items, 1)
		self.offset = self.offset + item.width + SCORE_SPACING
		if not item.once then table.insert(items, item) end
	end
end

---@private
---@param item ui.screens.main_menu_v2.StatusLine.Item
---@param x number
function StatusLine:drawItem(item, x)
	for _, part in ipairs(item.parts) do
		local font = part.font
		if font then
			Painter.setColorTable(part.color)
			lg.setFont(font)
			lg.print(part.text, math.floor(x), math.floor((HEIGHT - font:getHeight()) / 2))
			x = x + font:getWidth(part.text) + PART_GAP
		else
			local shader = self.avatar_shader or AvatarShader.new()
			self.avatar_shader = shader
			Painter.setColorRgb(1, 1, 1)
			local image = self.ui.api.online:getAvatar(part.avatar_url)
			AvatarShader.draw(shader, image, math.floor(x), (HEIGHT - AVATAR_SIZE) / 2, AVATAR_SIZE, AVATAR_RADIUS)
			x = x + AVATAR_SIZE + PART_GAP
		end
	end
end

function StatusLine:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.panel)
	lg.rectangle("fill", 0, 0, self.width, self.height)

	local title = self.ui.localization:get("main_menu.recent_scores")
	local title_font = Resources.getFont("cjk_bold", 15)
	local title_x = TITLE_MARGIN + LIVE_DOT + 10
	local run_x = self:getItemsX()

	-- When the items are shorter than the line, they follow themselves around until it is full.
	local items = self.items
	local x = run_x + self.offset
	local i = 1
	while items[1] and x < self.width do
		local item = items[i]
		if x + item.width > run_x then self:drawItem(item, x) end
		x = x + item.width + SCORE_SPACING
		i = i % #items + 1
	end

	-- The title covers the scores scrolling under it.
	Painter.setColorTable(Colors.panel)
	lg.rectangle("fill", 0, 0, run_x - TITLE_GAP, self.height)
	Painter.setColorTable(Colors.yellow)
	lg.circle("fill", TITLE_MARGIN + LIVE_DOT / 2, HEIGHT / 2, LIVE_DOT / 2, 16)
	Painter.setColorTable(Colors.muted)
	lg.setFont(title_font)
	lg.print(title, title_x, math.floor((HEIGHT - title_font:getHeight()) / 2))
end

return StatusLine
