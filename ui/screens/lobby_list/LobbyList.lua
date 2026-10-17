local Button = require("ui.views.Button")
local Colors = require("ui.Colors")
local Label = require("ui.views.Label")
local RoomList = require("ui.screens.lobby_list.RoomList")
local Screen = require("gui.Screen")
local UiActions = require("ui.UiActions")

---@class ui.screens.lobby_list.LobbyList : gui.Screen
---@operator call: ui.screens.lobby_list.LobbyList
---@field ui ui.UserInterface
---@field client sea.MultiplayerClient
---@field list ui.screens.lobby_list.RoomList
---@field empty ui.views.Label
---@field status ui.views.Label
---@field observer util.Observer?
---@field joining_room_id integer?
local LobbyList = Screen + {}

---@param ui ui.UserInterface
function LobbyList:new(ui)
	Screen.new(self)
	self.ui = ui
	self.client = ui.game.multiplayerModel.client
	self.observer = nil
	self.joining_room_id = nil
	self.root:setPivot(0.5, 0.5)

	local title = self.root:add(Label({
		font_name = "bold", font_size = 46, text = ui.localization:get("lobby_list.title"),
	}))
	title:setPosition(48, 36)

	self.status = self.root:add(Label({
		font_name = "regular", font_size = 18,
		text = ui.localization:get("lobby_list.select_room"), color = Colors.muted,
	}))
	self.status:setPosition(48, 96)

	self.list = self.root:add(RoomList(self.client, function(room)
		self:joinRoom(room)
	end))
	self.list:anchorFill(48, 140, 48, 92)

	self.empty = self.root:add(Label({
		font_name = "regular", font_size = 20,
		text = ui.localization:get("lobby_list.empty"), color = Colors.muted, align = "center",
	}))
	self.empty:setSize(720, 30):setAlignment(0.5, 0.5)

	local back = self.root:add(Button(ui.localization:get("lobby_list.back"), function()
		ui:setScreen(ui.main_menu, true)
	end, {variant = "secondary", shape = "capsule", font_name = "medium", font_size = 18}))
	back:setSize(160, 46):setAlignment(0, 1):addPosition(48, -24)

	local create = self.root:add(Button(ui.localization:get("lobby_list.create"), function()
		ui.modal_manager:attachCreateRoom()
	end, {variant = "primary", shape = "capsule", font_name = "medium", font_size = 18}))
	create:setSize(190, 46):setAlignment(1, 1):addPosition(-48, -24)
end

function LobbyList:load()
	Screen.load(self)
	self.observer = self.client:onChanged(self)
	self:refreshRooms()
end

function LobbyList:unload()
	if self.observer then
		self.client:offChanged(self.observer)
		self.observer = nil
	end
	Screen.unload(self)
end

function LobbyList:refreshRooms()
	self.list:setRooms(self.client.rooms)
	self.empty:setVisible(#self.client.rooms == 0)
end

---@param room sea.Room
function LobbyList:joinRoom(room)
	if self.joining_room_id then
		return
	end
	self.joining_room_id = room.id
	self.list:setEnabled(false)
	self.status:setText(self.ui.localization:get("lobby_list.joining", {room = room.name}))
	self.client:joinRoom(room.id, "")
end

---@param event sea.multi.MultiplayerClient.Event
function LobbyList:receive(event)
	if event.type == "rooms_changed" then
		self:refreshRooms()
	elseif event.type == "room_users_changed" and event.room_id == self.joining_room_id
		and self.ui.screen_manager.input_screen == self then
		self.joining_room_id = nil
		self.ui:setScreen(self.ui.lobby, true)
	elseif event.type == "join_failed" and event.room_id == self.joining_room_id then
		self.joining_room_id = nil
		self.list:setEnabled(true)
		self.status:setText(self.ui.localization:get("lobby_list.join_failed", {error = event.error}))
	end
end

function LobbyList:enter()
	self.ui.command_registry:pushContext("multiplayer", self.ui.multiplayer_commands)
	self:refreshRooms()
	self.joining_room_id = nil
	self.list:setEnabled(true)
	self.status:setText(self.ui.localization:get("lobby_list.select_room"))
	self.root:fadeIn(0.3, "OutCubic")
	self.root:scaleTo(1, 1, 0.3, "OutQuart")
end

function LobbyList:exit()
	Screen.exit(self)
	self.ui.command_registry:popContext("multiplayer")
	self.root:fadeOut(0.2, "OutQuad")
	self.root:scaleTo(1.01, 1.01, 0.3, "OutQuart")
	return true
end

---@param inputs gui.Inputs
function LobbyList:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.main_menu, true)
	end
end

return LobbyList
