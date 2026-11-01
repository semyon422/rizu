local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")
local AvatarShader = require("ui.views.AvatarShader")
local PlayerList = require("ui.screens.main_menu_v2.PlayerList")

local lg = love.graphics

local HEIGHT = 50
local PADDING = 12
local FACES = 5
local FACE_SIZE = 34
local FACE_OVERLAP = 8
local FACE_RADIUS = 6
local FACE_RING = 2
local LIVE_DOT = 8
local GAP = 12
local JOIN_TIME = 0.4 -- seconds the newest avatar takes to grow in
local LIST_WIDTH, LIST_HEIGHT = 420, 520
local LIST_HEADER = 44
local LIST_GAP = 6
local DIVIDER_COLOR = {0xF2 / 255, 0xF2 / 255, 1, 0.07}

---The dropdown with every online player, under the presence button.
---@class ui.screens.main_menu_v2.PresenceButton.List : gui.View
---@operator call: ui.screens.main_menu_v2.PresenceButton.List
---@field title string
---@field list ui.screens.main_menu_v2.PlayerList
local List = View + {}

---@param ui ui.UserInterface
---@param title string
function List:new(ui, title)
	View.new(self)
	self.title = title
	self.handles_mouse_input = true -- clicks inside do not close it
	local list = PlayerList(ui.localization, ui.api.online)
	list:setPlayers(ui.api.online:getOnlinePlayers())
	local rows = list:getRowCount()
	local height = math.min(LIST_HEIGHT, LIST_HEADER + 10 + rows * list.item_height + math.max(rows - 1, 0) * list.gap + 10)
	self:setSize(LIST_WIDTH, height)
	self.list = self:add(list)
	list:anchorFill(10, LIST_HEADER + 10, 10, 10)
end

---@return boolean handled
function List:onMouseDown() return true end

function List:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.panel)
	lg.rectangle("fill", 0, 0, self.width, self.height)
	local font = Resources.getFont("medium", 13)
	Painter.setColorTable(Colors.success)
	lg.circle("fill", 16 + LIVE_DOT / 2, LIST_HEADER / 2, LIVE_DOT / 2, 16)
	Painter.setColorTable(Colors.muted)
	lg.setFont(font)
	lg.print(self.title, 16 + LIVE_DOT + 10, math.floor((LIST_HEADER - font:getHeight()) / 2))
	Painter.setColorTable(DIVIDER_COLOR)
	lg.rectangle("fill", 0, LIST_HEADER, self.width, 1)
end

---Top bar of the main menu: the avatars of the latest players to come online and how many are online.
---A player coming online grows in at the front. A click lists everyone.
---@class ui.screens.main_menu_v2.PresenceButton : gui.View, ui.views.PopupOwner
---@operator call: ui.screens.main_menu_v2.PresenceButton
---@field ui ui.UserInterface
---@field players rizu.api.Online.Player[]
---@field text string
---@field joined number seconds since the front avatar came online, JOIN_TIME and over when settled
---@field popup ui.screens.main_menu_v2.PresenceButton.List?
---@field on_resize fun()? called when the width changes, so the top bar refits
---@field unsubscribes fun()[]
---@field avatar_shader love.Shader?
local PresenceButton = View + {}

---@param ui ui.UserInterface
---@param on_resize fun()?
function PresenceButton:new(ui, on_resize)
	View.new(self)
	self.ui = ui
	self.on_resize = on_resize
	self.players = {}
	self.text = ""
	self.joined = JOIN_TIME
	self.unsubscribes = {}
	self.handles_mouse_input = true
	self:setSize(0, HEIGHT)
end

function PresenceButton:load()
	local online = self.ui.api.online
	local function refresh() self:refresh() end
	self.unsubscribes = {
		online:on("account_changed", refresh),
		online:on("online_count_changed", refresh),
		online:on("online_players_changed", refresh),
		online:on("player_joined", function() self.joined = 0 end),
	}
	self:refresh()
end

function PresenceButton:unload()
	for _, unsubscribe in ipairs(self.unsubscribes) do unsubscribe() end
	self.unsubscribes = {}
	self:close()
end

function PresenceButton:refresh()
	local online = self.ui.api.online
	local localization = self.ui.localization
	self.players = online:getOnlinePlayers()
	local count = online:getOnlineCount()
	self.text = count and localization:get("main_menu.players_online", {count = count})
		or localization:get("song_select.offline")
	local width = PADDING * 2 + self:getFacesWidth() + LIVE_DOT + 8 + Resources.getFont("medium", 15):getWidth(self.text)
	if width ~= self:getAuthoredSize() then
		self:setWidth(width)
		if self.on_resize then self.on_resize() end
	end
end

---@private
---@return number
function PresenceButton:getFacesWidth()
	local faces = math.min(#self.players, FACES)
	if faces == 0 then return 0 end
	return faces * FACE_SIZE - (faces - 1) * FACE_OVERLAP + GAP
end

---@param dt number
function PresenceButton:update(dt)
	self.joined = math.min(self.joined + dt, JOIN_TIME)
end

---@param e gui.HoverEvent
function PresenceButton:onHover(e)
	Sounds.play("hover")
end

---@param e gui.MouseClickEvent
function PresenceButton:onMouseClick(e)
	if e.button ~= 1 then return end
	Sounds.play("click")
	if not self:close() then self:open() end
	return true
end

---@return boolean opened
function PresenceButton:open()
	if self.popup or #self.players == 0 then return false end
	local container = self.ui.overlay.popup_container
	local popup = List(self.ui, self.text)
	container:open(self, popup, self)
	popup:setOffset(self:getAuthoredSize() - LIST_WIDTH, HEIGHT + LIST_GAP)
	self.popup = popup
	return true
end

---@return boolean closed
function PresenceButton:close()
	local popup = self.popup
	if not popup then return false end
	self.popup = nil
	popup.parent:remove(popup)
	return true
end

function PresenceButton:draw()
	Painter.snapToPixel()
	if self.mouse_over or self.popup then
		Painter.setColorTable(Colors.surface_raised)
		lg.rectangle("fill", 0, 0, self.width, self.height)
	end

	-- Drawn back to front, so the newest avatar is on top at the left.
	local shader = self.avatar_shader or AvatarShader.new()
	self.avatar_shader = shader
	local online = self.ui.api.online
	local y = (HEIGHT - FACE_SIZE) / 2
	local grow = 1 - (1 - self.joined / JOIN_TIME) ^ 3
	for i = math.min(#self.players, FACES), 1, -1 do
		local x = PADDING + (i - 1) * (FACE_SIZE - FACE_OVERLAP)
		local size = FACE_SIZE
		if i == 1 then
			size = FACE_SIZE * grow
			x, y = x + (FACE_SIZE - size) / 2, (HEIGHT - size) / 2
		end
		Painter.setColorTable(Colors.background)
		lg.rectangle("fill", x - FACE_RING, y - FACE_RING, size + FACE_RING * 2, size + FACE_RING * 2, FACE_RADIUS + FACE_RING)
		Painter.setColorRgb(1, 1, 1)
		AvatarShader.draw(shader, online:getAvatar(self.players[i].avatar_url), x, y, size, FACE_RADIUS)
	end

	local x = PADDING + self:getFacesWidth()
	Painter.setColorTable(online:getOnlineCount() and Colors.success or Colors.muted)
	lg.circle("fill", x + LIVE_DOT / 2, HEIGHT / 2, LIVE_DOT / 2, 16)
	local font = Resources.getFont("medium", 15)
	Painter.setColorTable(self.mouse_over and Colors.text or Colors.muted)
	lg.setFont(font)
	lg.print(self.text, x + LIVE_DOT + 8, math.floor((HEIGHT - font:getHeight()) / 2))
end

return PresenceButton
