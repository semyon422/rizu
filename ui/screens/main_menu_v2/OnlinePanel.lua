local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local PlayerGrid = require("ui.screens.main_menu_v2.PlayerGrid")

local lg = love.graphics

local WIDTH, HEIGHT = 520, 320
local PADDING = 18
local HEADER_HEIGHT = 44
local DIVIDER_COLOR = {0xF2 / 255, 0xF2 / 255, 1, 0.07}

---Bottom left: how many players are online and a card for each of those logged in.
---@class ui.screens.main_menu_v2.OnlinePanel : gui.View
---@operator call: ui.screens.main_menu_v2.OnlinePanel
---@field ui ui.UserInterface
---@field grid ui.screens.main_menu_v2.PlayerGrid
---@field title string
---@field unsubscribes fun()[]
local OnlinePanel = View + {}

---@param ui ui.UserInterface
function OnlinePanel:new(ui)
	View.new(self)
	self.ui = ui
	self.title = ""
	self.unsubscribes = {}
	self:setSize(WIDTH, HEIGHT)
	self.grid = self:add(PlayerGrid(ui.localization, ui.api.online))
	self.grid:anchorFill(PADDING, HEADER_HEIGHT + 10, PADDING, 10)
end

function OnlinePanel:load()
	local online = self.ui.api.online
	local function refresh() self:refresh() end
	self.unsubscribes = {
		online:on("account_changed", refresh),
		online:on("online_count_changed", refresh),
		online:on("online_players_changed", refresh),
	}
	self:refresh()
end

function OnlinePanel:unload()
	for _, unsubscribe in ipairs(self.unsubscribes) do unsubscribe() end
	self.unsubscribes = {}
end

function OnlinePanel:refresh()
	local online = self.ui.api.online
	local localization = self.ui.localization
	local count = online:getOnlineCount()
	self.title = count and localization:get("song_select.online", {count = count})
		or localization:get("song_select.offline")
	self.grid:setPlayers(online:getOnlinePlayers())
end

function OnlinePanel:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.panel)
	lg.rectangle("fill", 0, 0, self.width, self.height)
	local font = Resources.getFont("medium", 13)
	lg.setFont(font)
	Painter.setColorTable(Colors.muted)
	lg.print(self.title, PADDING, math.floor((HEADER_HEIGHT - font:getHeight()) / 2))
	Painter.setColorTable(DIVIDER_COLOR)
	lg.rectangle("fill", 0, HEADER_HEIGHT, self.width, 1)
end

return OnlinePanel
