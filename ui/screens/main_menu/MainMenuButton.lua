local View = require("gui.View")
local Colors = require("ui.Colors")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local SpringValue = require("gui.anim.SpringValue")

---@alias ui.screens.main_menu.MainMenuButtonVariant "play"|"primary"|"secondary"|"danger"

---@class ui.screens.main_menu.MainMenuButton.Config
---@field variant? ui.screens.main_menu.MainMenuButtonVariant
---@field font_size? integer
---@field icon gui.Sprite
---@field get_beat_phase? fun(): number?
---@field get_bpm? fun(): number?

---@class ui.screens.main_menu.MainMenuButton : gui.View
---@operator call: ui.screens.main_menu.MainMenuButton
---@field text string
---@field on_click fun()?
---@field icon gui.Sprite
---@field font love.Font
---@field background gui.NineSliceUsage
---@field hover_background gui.NineSliceUsage
---@field pressed_background gui.NineSliceUsage
---@field pulse_outline gui.NineSliceUsage?
---@field get_beat_phase fun(): number?
---@field get_bpm fun(): number?
---@field pulse_phase number
local MainMenuButton = View + {}

local PLAY_PULSE_SCALE = 1.12
local DEFAULT_PULSE_DURATION = 1
local HOVER_ENTER_SPRING = {stiffness = 700, damping = 46}
local HOVER_EXIT_SPRING = {stiffness = 90, damping = 20}
local HORIZONTAL_PADDING = 20

---@param text string
---@param on_click fun()?
---@param config ui.screens.main_menu.MainMenuButton.Config
function MainMenuButton:new(text, on_click, config)
	View.new(self)
	local variant = config.variant or "secondary"
	assert(variant == "play" or variant == "primary" or variant == "secondary" or variant == "danger",
		"invalid main menu button variant")

	self.text = text
	self.on_click = on_click
	self.icon = assert(config.icon, "main menu button icon is required")
	self.font = Resources.getFont("bold", config.font_size or 18)
	local sprite_name = "button_" .. variant
	self.background = NineSliceUsage(Resources.nine_slices[sprite_name])
	self.hover_background = NineSliceUsage(Resources.nine_slices[sprite_name .. "_hover"])
	self.pressed_background = NineSliceUsage(Resources.nine_slices[sprite_name .. "_pressed"])
	if variant == "play" then
		self.pulse_outline = NineSliceUsage(Resources.nine_slices.button_play_pulse)
	end
	self.get_beat_phase = config.get_beat_phase or function() return nil end
	self.get_bpm = config.get_bpm or function() return nil end
	self.pulse_phase = 0
	self:setSize(320, 64)
	self:setPivot(0.5, 0.5)
	self.handles_mouse_input = true
	self.hover = SpringValue({stiffness = 300, damping = 30})
end

---@param e gui.MouseClickEvent
function MainMenuButton:onMouseClick(e)
	if e.button ~= 1 then return end
	if self.on_click then
		self.on_click()
		self:scaleTo(1, 1, 0.12, "OutCubic")
	end
	return true
end

---@param e gui.MouseDownEvent
function MainMenuButton:onMouseDown(e)
	if e.button == 1 then
		self:scaleTo(0.975, 0.975, 0.08, "OutQuad")
		return true
	end
end

---@param e gui.MouseUpEvent
function MainMenuButton:onMouseUp(e)
	if e.button == 1 then
		self:scaleTo(1, 1, 0.12, "OutCubic")
		return true
	end
end

function MainMenuButton:update(dt)
	self.hover:configure(self.mouse_over and HOVER_ENTER_SPRING or HOVER_EXIT_SPRING)
	self.hover:set(self.mouse_over and 1 or 0)
	self.hover:update(dt)
	local beat_phase = self.get_beat_phase()
	if beat_phase ~= nil then
		self.pulse_phase = beat_phase % 1
	else
		local bpm = self.get_bpm()
		local duration = bpm and bpm > 0 and bpm < math.huge and 60 / bpm or DEFAULT_PULSE_DURATION
		self.pulse_phase = (self.pulse_phase + dt / duration) % 1
	end
end

function MainMenuButton:drawPulseOutline()
	if not self.pulse_outline then return end

	local progress = self.pulse_phase
	local scale = 1 + (PLAY_PULSE_SCALE - 1) * progress
	local alpha = 1 - progress
	local width = self.width * scale
	local height = self.height * scale

	love.graphics.push("transform")
	love.graphics.translate((self.width - width) / 2, (self.height - height) / 2)
	Painter.setOpacity(alpha)
	self.pulse_outline:draw(width, height)
	Painter.setOpacity(1)
	love.graphics.pop()
end

function MainMenuButton:draw()
	local hover = math.max(0, math.min(1, self.hover:get()))
	self:drawPulseOutline()
	Painter.snapToPixel()
	Painter.setColorRgb(1, 1, 1)
	if self.pressed then
		self.pressed_background:draw(self.width, self.height)
	else
		self.background:draw(self.width, self.height)
		if hover > 0.001 then
			Painter.setOpacity(hover)
			self.hover_background:draw(self.width, self.height)
		end
	end

	Painter.setOpacity(1)
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font)
	local icon_width, icon_height = self.icon:getDimensions()
	local pressed_offset = self.pressed and 1 or 0
	love.graphics.print(
		self.text,
		HORIZONTAL_PADDING,
		(self.height - self.font:getHeight()) / 2 + pressed_offset
	)
	self.icon:draw(
		self.width - HORIZONTAL_PADDING - icon_width,
		(self.height - icon_height) / 2 + pressed_offset
	)
end

return MainMenuButton
