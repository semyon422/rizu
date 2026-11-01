local VirtualizedList = require("gui.VirtualizedList")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local AvatarShader = require("ui.views.AvatarShader")
local ChartCarousel = require("ui.screens.song_select_v2.ChartCarousel")

local lg = love.graphics

local COLUMNS = 2
local GAP = 10
local PADDING = 8
local AVATAR_SIZE = 48
local AVATAR_RADIUS = 8
local LINE_GAP = 2
---@type {[string]: gui.Color}
local ROLE_COLORS = {admin = Colors.danger, donator = Colors.yellow}

---Online players in a scrolling grid of cards, drawn only for the rows on screen: avatar, the name
---in its role's color, plays and play time.
---@class ui.screens.main_menu_v2.PlayerGrid : gui.VirtualizedList
---@operator call: ui.screens.main_menu_v2.PlayerGrid
---@field localization ui.localization.Localization
---@field online rizu.api.Online
---@field players rizu.api.Online.Player[]
---@field fitted {[integer]: {name: string, stats: string}} texts cut to the card, by index
---@field avatar_shader love.Shader?
local PlayerGrid = VirtualizedList + {}

---@param localization ui.localization.Localization
---@param online rizu.api.Online
function PlayerGrid:new(localization, online)
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
function PlayerGrid:getItemCount() return #self.players end

---@return integer
function PlayerGrid:getColumnCount() return COLUMNS end

---@param players rizu.api.Online.Player[]
function PlayerGrid:setPlayers(players)
	self.players = players
	self.fitted = {}
end

---@private
---@param index integer
---@param width number
---@return {name: string, stats: string}
function PlayerGrid:getTexts(index, width)
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

---@private
---@param player rizu.api.Online.Player
---@param x number
---@param y number
function PlayerGrid:drawAvatar(player, x, y)
	local shader = self.avatar_shader or AvatarShader.new()
	self.avatar_shader = shader
	AvatarShader.setRect(shader, x, y, AVATAR_SIZE, AVATAR_SIZE, AVATAR_RADIUS)
	Painter.setColorRgb(1, 1, 1)
	lg.setShader(shader)
	local image = self.online:getAvatar(player.avatar_url)
	if image then
		local w, h = image:getDimensions()
		local scale = math.max(AVATAR_SIZE / w, AVATAR_SIZE / h)
		lg.draw(image, x + (AVATAR_SIZE - w * scale) / 2, y + (AVATAR_SIZE - h * scale) / 2, 0, scale)
	else
		local sprite = Resources.sprites.avatar
		local w, h = sprite:getDimensions()
		local scale = math.max(AVATAR_SIZE / w, AVATAR_SIZE / h)
		sprite:draw(x + (AVATAR_SIZE - w * scale) / 2, y + (AVATAR_SIZE - h * scale) / 2, 0, scale, scale)
	end
	lg.setShader()
end

function PlayerGrid:draw()
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
			self:drawAvatar(player, x + PADDING, y + PADDING)
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

return PlayerGrid
