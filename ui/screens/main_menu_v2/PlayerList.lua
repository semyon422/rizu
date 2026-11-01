local VirtualizedList = require("gui.VirtualizedList")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local AvatarShader = require("ui.views.AvatarShader")
local ChartCarousel = require("ui.screens.song_select_v2.ChartCarousel")

local lg = love.graphics

local COLUMNS = 1
local GAP = 10
local PADDING = 8
local AVATAR_SIZE = 48
local AVATAR_RADIUS = 8
local LINE_GAP = 2
---@type {[string]: gui.Color}
local ROLE_COLORS = {admin = Colors.danger, donator = Colors.yellow}

---Online players in a scrolling list of cards, drawn only for the rows on screen: avatar, the name
---in its role's color, plays and play time.
---@class ui.screens.main_menu_v2.PlayerList : gui.VirtualizedList
---@operator call: ui.screens.main_menu_v2.PlayerList
---@field localization ui.localization.Localization
---@field online rizu.api.Online
---@field players rizu.api.Online.Player[]
---@field fitted {[integer]: {name: string, stats: string}} texts cut to the card, by index
---@field avatar_shader love.Shader?
local PlayerList = VirtualizedList + {}

---@param localization ui.localization.Localization
---@param online rizu.api.Online
function PlayerList:new(localization, online)
	VirtualizedList.new(self)
	self.localization = localization
	self.online = online
	self.item_height = AVATAR_SIZE + PADDING * 2
	self.gap = GAP
	self.players = {}
	self.fitted = {}
	self.font = Resources.getFont("cjk_bold", 18)
	self.stats_font = Resources.getFont("regular", 14)
end

---@return integer
function PlayerList:getItemCount() return #self.players end

---@return integer
function PlayerList:getColumnCount() return COLUMNS end

---@param players rizu.api.Online.Player[]
function PlayerList:setPlayers(players)
	self.players = players
	self.fitted = {}
end

---@private
---@param index integer
---@param width number
---@return {name: string, stats: string}
function PlayerList:getTexts(index, width)
	local texts = self.fitted[index]
	if texts then return texts end
	local player = self.players[index]
	local stats = self.localization:get("main_menu.player_stats", {
		plays = player.chartplays_count,
		hours = math.floor(player.play_time / 3600),
		minutes = math.floor(player.play_time % 3600 / 60),
	})
	texts = {
		name = ChartCarousel.fitText(self.font, player.name, width),
		stats = ChartCarousel.fitText(self.stats_font, stats, width),
	}
	self.fitted[index] = texts
	return texts
end

function PlayerList:draw()
	local font, stats_font = self.font, self.stats_font
	local card_width = math.floor((self.width - GAP * (COLUMNS - 1)) / COLUMNS)
	local name_x = PADDING * 2 + AVATAR_SIZE
	local name_width = card_width - name_x - PADDING
	local text_height = font:getHeight() + LINE_GAP + stats_font:getHeight()
	local name_y = math.floor((self.item_height - text_height) / 2)
	local stats_y = name_y + font:getHeight() + LINE_GAP
	local scroll = self:getVisualScrollPosition()
	local first_row, last_row = self:getVisibleRowRange()
	for row = first_row, last_row do
		local y = math.floor((row - 1) * self:getRowStep() - scroll)
		for column = 1, COLUMNS do
			local index = (row - 1) * COLUMNS + column
			local player = self.players[index]
			if not player then break end
			local x = (column - 1) * (card_width + GAP)
			Painter.setColorTable(Colors.surface)
			lg.rectangle("fill", x, y, card_width, self.item_height, AVATAR_RADIUS)
			local shader = self.avatar_shader or AvatarShader.new()
			self.avatar_shader = shader
			Painter.setColorRgb(1, 1, 1)
			AvatarShader.draw(shader, self.online:getAvatar(player.avatar_url), x + PADDING, y + PADDING, AVATAR_SIZE, AVATAR_RADIUS)
			local texts = self:getTexts(index, name_width)
			Painter.setColorTable(ROLE_COLORS[player.role] or Colors.text)
			lg.setFont(font)
			lg.print(texts.name, x + name_x, y + name_y)
			Painter.setColorTable(Colors.muted)
			lg.setFont(stats_font)
			lg.print(texts.stats, x + name_x, y + stats_y)
		end
	end
end

return PlayerList
