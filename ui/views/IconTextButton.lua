local View = require("gui.View")
local NineSliceUsage = require("gui.NineSliceUsage")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")
local SpringValue = require("gui.anim.SpringValue")

---@alias ui.views.IconTextButton.Variant "secondary"|"danger"|"success"

---@class ui.views.IconTextButton.Config
---@field text string
---@field icon gui.Sprite
---@field variant? ui.views.IconTextButton.Variant
---@field icon_after? boolean
---@field icon_color? gui.Color
---@field badge? string
---@field font_size? integer
---@field gap? number Between the icon and the text.
---@field padding_left? number
---@field padding_right? number
---@field on_click? fun()

---A rounded button with an icon, a label and an optional count badge. Its width follows the content.
---@class ui.views.IconTextButton : gui.View
---@operator call: ui.views.IconTextButton
---@field text string
---@field icon gui.Sprite
---@field icon_after boolean
---@field icon_color gui.Color
---@field badge string?
---@field preferred_width number
---@field on_click fun()?
local IconTextButton = View + {}

IconTextButton.HEIGHT = 56

local ICON_SIZE = 24
local BADGE_GAP = 14
local BADGE_PADDING_X = 8
local BADGE_PADDING_Y = 2
local ACTIVE_OPACITY = 0.32
local HOVER_ENTER_SPRING = {stiffness = 700, damping = 46}
local HOVER_EXIT_SPRING = {stiffness = 90, damping = 20}

---@param config ui.views.IconTextButton.Config
function IconTextButton:new(config)
	View.new(self)
	local variant = config.variant or "secondary"
	assert(variant == "secondary" or variant == "danger" or variant == "success", "invalid button variant")
	self.text = config.text
	self.icon = config.icon
	self.icon_after = config.icon_after or false
	self.icon_color = config.icon_color or Colors.text
	self.badge = config.badge
	self.gap = config.gap or 12
	self.padding_left = config.padding_left or 18
	self.padding_right = config.padding_right or 22
	self.on_click = config.on_click
	self.font = Resources.getFont("bold", config.font_size or 16)
	self.badge_font = Resources.getFont("bold", 14)
	self.background = NineSliceUsage(Resources.nine_slices["icon_text_button_" .. variant])
	self.hover_background = NineSliceUsage(Resources.nine_slices["icon_text_button_" .. variant .. "_hover"])
	self.active_background = NineSliceUsage(Resources.nine_slices.icon_text_button_active)
	self.badge_background = NineSliceUsage(Resources.nine_slices.icon_text_button_badge)
	self.hover = SpringValue({stiffness = 300, damping = 30})
	self.handles_mouse_input = true
	self:setPivot(0.5, 0.5)
	self:updateSize()
end

---@private
---@return number
function IconTextButton:getBadgeWidth()
	return self.badge_font:getWidth(self.badge) + BADGE_PADDING_X * 2
end

---@private
function IconTextButton:updateSize()
	local width = self.padding_left + ICON_SIZE + self.gap + self.font:getWidth(self.text) + self.padding_right
	if self.badge then
		width = width + BADGE_GAP + self:getBadgeWidth()
	end
	self.preferred_width = width
	self:setSize(width, IconTextButton.HEIGHT)
end

---The content width, known before layout resolves `width`.
---@return number
function IconTextButton:getPreferredWidth()
	return self.preferred_width
end

---@param badge string?
function IconTextButton:setBadge(badge)
	if self.badge == badge then
		return
	end
	self.badge = badge
	self:updateSize()
end

---@param e gui.HoverEvent
function IconTextButton:onHover(e)
	if self.effective_enabled then
		Sounds.play("hover")
	end
end

---@param e gui.MouseClickEvent
function IconTextButton:onMouseClick(e)
	if e.button ~= 1 or not self.effective_enabled then
		return
	end
	if self.on_click then
		self.on_click()
	end
	Sounds.play("click")
	return true
end

function IconTextButton:onMouseDown(e)
	if e.button == 1 and self.effective_enabled then
		self:scaleTo(0.975, 0.975, 0.08, "OutQuad")
		return true
	end
end

function IconTextButton:onMouseUp(e)
	if e.button == 1 then
		self:scaleTo(1, 1, 0.12, "OutCubic")
		return true
	end
end

---@param dt number
function IconTextButton:update(dt)
	local hovered = self.mouse_over and self.effective_enabled
	self.hover:configure(hovered and HOVER_ENTER_SPRING or HOVER_EXIT_SPRING)
	self.hover:set(hovered and 1 or 0)
	self.hover:update(dt)
end

function IconTextButton:draw()
	local lg = love.graphics
	local enabled_opacity = self.effective_enabled and 1 or 0.55
	local hover = math.max(0, math.min(1, self.hover:get()))
	Painter.snapToPixel()
	Painter.setOpacity(enabled_opacity)
	Painter.setColorRgb(1, 1, 1)
	self.background:draw(self.width, self.height)
	if (tonumber(self.badge) or 0) > 0 then
		local color = self.icon_color
		Painter.setColorRgb(color[1], color[2], color[3], ACTIVE_OPACITY)
		self.active_background:draw(self.width, self.height)
		Painter.setColorRgb(1, 1, 1)
	end
	if hover > 0.001 then
		Painter.setOpacity(enabled_opacity * hover)
		self.hover_background:draw(self.width, self.height)
		Painter.setOpacity(enabled_opacity)
	end

	local text_width = self.font:getWidth(self.text)
	local icon_x = self.padding_left
	local text_x = icon_x + ICON_SIZE + self.gap
	if self.icon_after then
		text_x = self.padding_left
		icon_x = text_x + text_width + self.gap
	end

	Painter.setColorTable(self.icon_color)
	local icon_width, icon_height = self.icon:getDimensions()
	self.icon:draw(icon_x + (ICON_SIZE - icon_width) / 2, (self.height - icon_height) / 2)

	Painter.setColorTable(Colors.text)
	lg.setFont(self.font)
	lg.print(self.text, text_x, (self.height - self.font:getHeight()) / 2)

	if self.badge then
		local badge_width = self:getBadgeWidth()
		local badge_height = self.badge_font:getHeight() + BADGE_PADDING_Y * 2
		Painter.setColorRgb(1, 1, 1)
		lg.push("transform")
		lg.translate(
			math.max(icon_x + ICON_SIZE, text_x + text_width) + BADGE_GAP,
			math.floor((self.height - badge_height) / 2)
		)
		self.badge_background:draw(badge_width, badge_height)
		Painter.setColorTable(Colors.muted)
		lg.setFont(self.badge_font)
		lg.printf(self.badge, 0, BADGE_PADDING_Y, badge_width, "center")
		lg.pop()
	end
	Painter.setOpacity(1)
end

return IconTextButton
