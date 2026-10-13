local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")
local ToolbarBackground = require("ui.screens.song_select_v2.ToolbarBackground")

---Switches the lists between the charts on this computer and the remote catalog.
---@class ui.screens.song_select_v2.OnlineButton : gui.View
---@operator call: ui.screens.song_select_v2.OnlineButton
local OnlineButton = View + {}

---@param ui ui.UserInterface
function OnlineButton:new(ui)
	View.new(self)
	self.ui = ui
	self.label_font = Resources.getFont("bold", 9)
	self.value_font = Resources.getFont("bold", 14)
	self.background = ToolbarBackground()
	self.handles_mouse_input = true
end

---@return boolean
function OnlineButton:isOnline()
	return self.ui.api.charts:getSource() == "online"
end

---@param e gui.HoverEvent
function OnlineButton:onHover(e)
	if self.effective_enabled then
		Sounds.play("hover")
	end
end

---@param e gui.MouseClickEvent
---@return boolean?
function OnlineButton:onMouseClick(e)
	if e.button ~= 1 or not self.effective_enabled then
		return
	end
	local charts = self.ui.api.charts
	charts:setSource(self:isOnline() and "local" or "online")
	Sounds.play("click")
	return true
end

function OnlineButton:draw()
	local online = self:isOnline()
	Painter.snapToPixel()
	self.background:draw(self.width, self.height, assert(self.screen).ui_scale, self.mouse_over or online)

	local icon = Resources.sprites.icon_download
	local width, height = icon:getDimensions()
	local scale = math.min(20 / width, 20 / height)
	Painter.setColorTable(online and Colors.accent or Colors.muted)
	icon:draw(14, (self.height - height * scale) / 2, 0, scale, scale)

	local localization = self.ui.localization
	Painter.setColorTable(Colors.muted)
	love.graphics.setFont(self.label_font)
	love.graphics.print(localization:get("song_select.online_charts"), 45, 7)
	Painter.setColorTable(online and Colors.accent or Colors.text)
	love.graphics.setFont(self.value_font)
	love.graphics.print(localization:get(online and "song_select.online_on" or "song_select.online_off"), 45, 21)
end

return OnlineButton
