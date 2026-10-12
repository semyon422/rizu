local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local TrackContainer = require("gui.layout.TrackContainer")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Panel = require("ui.views.Panel")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local PlayerInfo = require("ui.views.PlayerInfo")
local SessionInfo = require("ui.screens.song_select_v2.SessionInfo")
local HeaderButton = require("ui.screens.song_select_v2.HeaderButton")

---Copy of the old header on a translucent strip, laid out after result_design/select.html.
---@class ui.screens.song_select_v2.Header : gui.View
---@operator call: ui.screens.song_select_v2.Header
---@field ui ui.UserInterface
---@field actions gui.layout.FlowContainer
---@field session_info ui.screens.song_select_v2.SessionInfo
---@field player_info ui.views.PlayerInfo
---@field unsubscribes fun()[]
local Header = View + {}

Header.HEIGHT = 52

local EDGE = 24
local BUTTON_WIDTH = 42
-- Header buttons centre a 20px icon; this puts the last icon on the edge margin.
local BUTTON_INSET = 11
local BACKGROUND_COLOR = {Colors.background[1], Colors.background[2], Colors.background[3], 0.55}
local LINE_COLOR = {Colors.outline[1], Colors.outline[2], Colors.outline[3], 0.5}

---@param ui ui.UserInterface
function Header:new(ui)
	View.new(self)
	self.ui = ui
	self:add(Panel({color = BACKGROUND_COLOR, line_color = LINE_COLOR, lines = {bottom = true}}))
		:anchorFill(0, 0, 0, 0)

	local brand = self:add(FlowContainer({direction = "row", gap = 12, align = 0.5}))
	local logo = brand:add(Image(Resources.sprites.rizu_logo, "fit"))
	logo:setSize(34, 34)
	brand:add(Label({font_name = "bold", font_size = 20, text = "RIZU"}))
	brand:fitContent()
	brand:anchorFixed(EDGE, 0, brand.width, Header.HEIGHT)

	local session_info = self:add(SessionInfo(ui.localization:get("song_select.offline"), true))
	session_info:setAlignment(0.5, 0.5)
	self.session_info = session_info

	local actions = self:add(FlowContainer({direction = "row", align = 0.5}))
	self.actions = actions
	self.player_info = actions:add(PlayerInfo(ui.localization:get("song_select.username")))

	local buttons = actions:add(TrackContainer({direction = "row"}))
	buttons:setSize(BUTTON_WIDTH * 4, 50)
	buttons:add(HeaderButton(Resources.sprites.icon_gear, function()
		ui.modal_manager:attachConfig()
	end), BUTTON_WIDTH)
	buttons:add(HeaderButton(Resources.sprites.icon_download, function()
		ui:setScreen(ui.dlc, true)
	end), BUTTON_WIDTH)
	buttons:add(HeaderButton(Resources.sprites.icon_folder, function()
		ui:setScreen(ui.locations, true)
	end), BUTTON_WIDTH)
	buttons:add(HeaderButton(Resources.sprites.icon_terminal, function()
		ui.modal_manager:attachPalette()
	end), BUTTON_WIDTH)
	actions:fitContent()
	actions:setAlignment(1, 0.5):addPosition(BUTTON_INSET - EDGE, 0)
	self:updatePlayerInfo()
end

function Header:load()
	local online = self.ui.api.online
	local function update() self:updatePlayerInfo() end
	self.unsubscribes = {online:on("account_changed", update), online:on("online_count_changed", update)}
	self:updatePlayerInfo()
end

function Header:unload()
	for _, unsubscribe in ipairs(self.unsubscribes or {}) do
		unsubscribe()
	end
	self.unsubscribes = {}
end

function Header:updatePlayerInfo()
	local online = self.ui.api.online
	self.player_info:updateText(online:getUsername() or self.ui.localization:get("song_select.username"))
	self.player_info:updateAvatar(online:getAvatarUrl(), online)
	self.actions:fitContent()

	local count = online:getOnlineCount()
	if count then
		self.session_info:setStatusText(self.ui.localization:get("song_select.online", {count = count}))
	else
		self.session_info:setStatusText(self.ui.localization:get("song_select.offline"))
	end
end

return Header
