local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local VirtualizedList = require("gui.VirtualizedList")

---@class ui.screens.lobby_list.RoomList : gui.VirtualizedList
---@operator call: ui.screens.lobby_list.RoomList
---@field rooms sea.Room[]
---@field client sea.MultiplayerClient
---@field hover_index integer?
---@field on_join fun(room: sea.Room)?
local RoomList = VirtualizedList + {}

local ITEM_HEIGHT = 82
local PADDING = 18

---@param client sea.MultiplayerClient
---@param on_join fun(room: sea.Room)?
function RoomList:new(client, on_join)
	VirtualizedList.new(self)
	self.item_height = ITEM_HEIGHT
	self.gap = 6
	self.client = client
	self.rooms = {}
	self.hover_index = nil
	self.on_join = on_join
	self.title_font = Resources.getFont("cjk_bold", 21)
	self.detail_font = Resources.getFont("cjk_regular", 15)
end

---@return integer
function RoomList:getItemCount()
	return #self.rooms
end

---@param rooms sea.Room[]
function RoomList:setRooms(rooms)
	self.rooms = rooms
	self.hover_index = nil
	self:stopScrollMotion()
	self:scrollTo(0, true)
end

---@param screen_x number
---@param screen_y number
---@return integer?
function RoomList:getIndexAt(screen_x, screen_y)
	local local_y = self:getLocalY(screen_x, screen_y)
	if local_y < 0 or local_y >= self.height then
		return
	end
	local index = math.floor((local_y + self:getVisualScrollPosition()) / self:getRowStep()) + 1
	if index < 1 or index > #self.rooms then
		return
	end
	return index
end

---@param dt number
function RoomList:update(dt)
	VirtualizedList.update(self, dt)
	self.hover_index = nil
	if self.mouse_over then
		self.hover_index = self:getIndexAt(love.mouse.getPosition())
	end
end

---@param e gui.MouseClickEvent
---@return boolean?
function RoomList:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	local index = self:getIndexAt(e.x, e.y)
	if not index then
		return
	end
	if self.on_join then
		self.on_join(self.rooms[index])
	end
	return true
end

---@param room sea.Room
---@return string
function RoomList:getHostName(room)
	local host = self.client:getUser(room.host_user_id)
	return host and host.name or ("#%d"):format(room.host_user_id)
end

function RoomList:draw()
	local previous_font = love.graphics.getFont()
	local scroll = self:getVisualScrollPosition()
	local first_index, last_index = self:getVisibleRowRange()
	for index = first_index, last_index do
		local room = self.rooms[index]
		local y = (index - 1) * self:getRowStep() - scroll
		local hovered = index == self.hover_index
		Painter.setColorTable(hovered and Colors.surface_raised
			or (index % 2 == 0 and Colors.surface or Colors.panel))
		Resources.sprites.pixel:draw(0, y, 0, self.width, self.item_height)

		Painter.setColorTable(Colors.text)
		love.graphics.setFont(self.title_font)
		love.graphics.print(room.name, PADDING, y + 10)

		local chart = room.chartmeta_key
		local chart_text = chart and chart.hash and chart.index
			and (("%.8s / %d"):format(tostring(chart.hash), chart.index)) or "-"
		local status = (room.isPlaying or room.is_playing) and "playing" or "waiting"
		local details = ("Host: %s  |  Chart: %s  |  %s"):format(
			self:getHostName(room), chart_text, status
		)
		Painter.setColorTable(Colors.muted)
		love.graphics.setFont(self.detail_font)
		love.graphics.print(details, PADDING, y + 48)
	end
	love.graphics.setFont(previous_font)
end

return RoomList
