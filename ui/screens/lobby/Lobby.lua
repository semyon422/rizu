local Button = require("ui.views.Button")
local Colors = require("ui.Colors")
local Label = require("ui.views.Label")
local Panel = require("ui.views.Panel")
local Screen = require("gui.Screen")
local UiActions = require("ui.UiActions")

---@class ui.screens.lobby.Lobby : gui.Screen
---@operator call: ui.screens.lobby.Lobby
---@field ui ui.UserInterface
---@field client sea.MultiplayerClient
---@field room_name ui.views.Label
---@field room_details ui.views.Label
---@field room_chart ui.views.Label
---@field observer util.Observer?
local Lobby = Screen + {}

---@param ui ui.UserInterface
function Lobby:new(ui)
	Screen.new(self)
	self.ui = ui
	self.client = ui.game.multiplayerModel.client
	self.observer = nil
	self.root:setPivot(0.5, 0.5)

	local title = self.root:add(Label({
		font_name = "bold", font_size = 46, text = ui.localization:get("lobby.title"),
	}))
	title:setPosition(48, 36)

	local subtitle = self.root:add(Label({
		font_name = "regular", font_size = 18,
		text = ui.localization:get("lobby.subtitle"), color = Colors.muted,
	}))
	subtitle:setPosition(48, 96)

	local panel = self.root:add(Panel({color = Colors.panel, line_color = Colors.outline}))
	panel:anchorFill(48, 140, 48, 100)

	self.room_name = panel:add(Label({font_name = "bold", font_size = 34}))
	self.room_name:setPosition(32, 28)
	self.room_details = panel:add(Label({font_name = "medium", font_size = 18, color = Colors.muted}))
	self.room_details:setPosition(32, 86)
	self.room_chart = panel:add(Label({font_name = "regular", font_size = 17, color = Colors.muted}))
	self.room_chart:setPosition(32, 126)

	local leave = self.root:add(Button(ui.localization:get("lobby.leave"), function()
		self:leaveRoom()
	end, {variant = "danger", shape = "capsule", font_name = "medium", font_size = 18}))
	leave:setSize(180, 46):setAlignment(0, 1):addPosition(48, -28)
end

function Lobby:load()
	Screen.load(self)
	self.observer = self.client:onChanged(self)
	self:refreshRoom()
end

function Lobby:unload()
	if self.observer then
		self.client:offChanged(self.observer)
		self.observer = nil
	end
	Screen.unload(self)
end

function Lobby:refreshRoom()
	local room = self.client:getMyRoom()
	if not room then
		self.room_name:setText(self.ui.localization:get("lobby.unavailable"))
		self.room_details:setText("")
		self.room_chart:setText("")
		return
	end

	local host = self.client:getUser(room.host_user_id)
	local host_name = host and host.name or ("#%d"):format(room.host_user_id)
	self.room_name:setText(room.name)
	self.room_details:setText(self.ui.localization:get("lobby.details", {
		id = room.id,
		host = host_name,
		players = #self.client.room_users,
		status = self.ui.localization:get((room.isPlaying or room.is_playing)
			and "lobby.status_playing" or "lobby.status_waiting"),
	}))

	local chart = room.chartmeta_key
	if chart and chart.hash and chart.index then
		self.room_chart:setText(self.ui.localization:get("lobby.chart", {
			chart = ("%.8s / %d"):format(tostring(chart.hash), chart.index),
		}))
	else
		self.room_chart:setText(self.ui.localization:get("lobby.no_chart"))
	end
end

function Lobby:leaveRoom()
	self.client:leaveRoom()
	self.ui:setScreen(self.ui.lobby_list, true)
end

---@param event sea.multi.MultiplayerClient.Event
function Lobby:receive(event)
	if event.type == "rooms_changed" or event.type == "users_changed" or event.type == "room_users_changed" then
		self:refreshRoom()
		if not self.client:isInRoom() and self.ui.screen_manager.input_screen == self then
			self.ui:setScreen(self.ui.lobby_list, true)
		end
	end
end

function Lobby:enter()
	self.ui.command_registry:pushContext("multiplayer", self.ui.multiplayer_commands)
	self:refreshRoom()
	self.root:fadeIn(0.3, "OutCubic")
	self.root:scaleTo(1, 1, 0.3, "OutQuart")
end

function Lobby:exit()
	Screen.exit(self)
	self.ui.command_registry:popContext("multiplayer")
	self.root:fadeOut(0.2, "OutQuad")
	self.root:scaleTo(1.01, 1.01, 0.3, "OutQuart")
	return true
end

---@param inputs gui.Inputs
function Lobby:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.cancel) then
		self:leaveRoom()
	end
end

return Lobby
