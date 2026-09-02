local View = require("gui.View")
local Color = require("ui.Color")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")

---@class ui.screens.song_select.FooterButton.Config
---@field width number
---@field height number
---@field color gui.Color
---@field text string
---@field icon gui.Sprite
---@field icon_after? boolean
---@field badge? string
---@field large? boolean
---@field on_click? fun()

---@class ui.screens.song_select.FooterButton : gui.View
---@operator call: ui.screens.song_select.FooterButton
---@field control_color gui.Color
---@field text string
---@field icon gui.Sprite
---@field badge string?
---@field on_click fun()?
local FooterButton = View + {}

local ICON_SIZE = 24
local GAP = 9
local LARGE_GAP = 10

---@param config ui.screens.song_select.FooterButton.Config
function FooterButton:new(config)
	View.new(self)
	self.control_color = config.color
	self.text = config.text
	self.icon = config.icon
	self.badge = config.badge
	self.icon_after = config.icon_after or false
	self.large = config.large or false
	self.on_click = config.on_click
	self.font = Resources.getFont("bold", self.large and 16 or 12)
	self.handles_mouse_input = true
	self:setSize(config.width, config.height)
end

---@param badge string?
function FooterButton:setBadge(badge)
	self.badge = badge
end

---@param active boolean
function FooterButton:setActive(active)
	self.active = active
end

---@param e gui.HoverEvent
function FooterButton:onHover(e)
	if self.effective_enabled then
		Sounds.play("hover")
	end
end

---@param e gui.MouseClickEvent
function FooterButton:onMouseClick(e)
	if e.button ~= 1 or not self.effective_enabled then
		return
	end
	if self.on_click then
		self.on_click()
	end
	Sounds.play("click")
	return true
end

local background = {0, 0, 0, 1}
local highlight = {0, 0, 0, 1}
local icon_color = {0, 0, 0, 1}
local badge_color = {Colors.background[1], Colors.background[2], Colors.background[3], 0.6}

function FooterButton:draw()
	Painter.snapToPixel()
	local hovered = self.mouse_over and self.effective_enabled
	if self.large then
		Color.mix_to(background, self.control_color, Colors.background, hovered and 0.08 or 0.22)
	else
		local control_mix = self.active and 0.65 or hovered and 0.3 or 0.2
		Color.mix_to(background, Colors.surface, self.control_color, control_mix)
	end
	Color.mix_to(highlight, self.control_color, Colors.text, self.large and 0.2 or 0.45)
	Color.mix_to(icon_color, self.control_color, Colors.text, 0.24)

	if not self.effective_enabled then
		Painter.setOpacity(0.55)
	end
	Painter.setColorTable(background)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
	if not self.large then
		Painter.setColorTable(highlight)
		Resources.sprites.pixel:draw(0, 0, 0, self.width, 3)
	end

	local icon_width = ICON_SIZE
	local icon_height = ICON_SIZE
	local gap = self.large and LARGE_GAP or GAP
	local text_width = self.font:getWidth(self.text)
	local badge_width = self.badge and math.max(18, self.font:getWidth(self.badge) + 10) or 0
	local badge_gap = self.badge and GAP or 0
	local content_width = icon_width + gap + text_width + badge_gap + badge_width
	local x = (self.width - content_width) / 2
	local text_x
	local icon_x
	if self.icon_after then
		text_x = x
		icon_x = x + text_width + gap
	else
		icon_x = x
		text_x = x + icon_width + gap
	end

	Painter.setColorTable(self.large and Colors.text or icon_color)
	local source_width, source_height = self.icon:getDimensions()
	self.icon:draw(
		icon_x + (icon_width - source_width) / 2,
		(self.height - source_height) / 2
	)

	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font)
	love.graphics.print(self.text, text_x, (self.height - self.font:getHeight()) / 2)

	if self.badge then
		local badge_x = text_x + text_width + badge_gap
		local badge_height = 18
		local badge_y = (self.height - badge_height) / 2
		Painter.setColorTable(badge_color)
		Resources.sprites.pixel:draw(badge_x, badge_y, 0, badge_width, badge_height)
		Painter.setColorTable(Colors.text)
		love.graphics.printf(self.badge, badge_x, badge_y + (badge_height - self.font:getHeight()) / 2, badge_width, "center")
	end
	Painter.setOpacity(1)
end

return FooterButton
