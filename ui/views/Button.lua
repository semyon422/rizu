local View = require("gui.View")
local Colors = require("ui.Colors")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local SpringValue = require("gui.anim.SpringValue")

---@alias ui.views.ButtonVariant "primary"|"secondary"|"danger"|"success"
---@alias ui.views.ButtonShape "default"|"capsule"

---@class ui.views.ButtonConfig
---@field variant? ui.views.ButtonVariant
---@field shape? ui.views.ButtonShape
---@field font_name? ui.FontName
---@field font_size? integer

---@class ui.views.Button : gui.View
---@operator call: ui.views.Button
---@field text string
---@field on_click fun()?
---@field font love.Font
---@field background gui.NineSliceUsage
---@field hover_background gui.NineSliceUsage
---@field pressed_background gui.NineSliceUsage
---@field shape ui.views.ButtonShape
local Button = View + {}

local HOVER_ENTER_SPRING = {stiffness = 700, damping = 46}
local HOVER_EXIT_SPRING = {stiffness = 90, damping = 20}

---@param text string
---@param on_click fun()?
---@param config ui.views.ButtonConfig?
function Button:new(text, on_click, config)
	View.new(self)
	config = config or {}
	local variant = config.variant or "secondary"
	local shape = config.shape or "default"
	assert(variant == "primary" or variant == "secondary" or variant == "danger" or variant == "success",
		"invalid button variant")
	assert(shape == "default" or shape == "capsule", "invalid button shape")
	self.text = text
	self.on_click = on_click
	self.font = Resources.getFont(config.font_name or "bold", config.font_size or 24)
	self.shape = shape
	self:setVariant(variant)
	self:setSize(320, 64)
	self:setPivot(0.5, 0.5)
	self.handles_mouse_input = true
	self.hover = SpringValue({stiffness = 300, damping = 30})
end

---@param variant ui.views.ButtonVariant
function Button:setVariant(variant)
	assert(variant == "primary" or variant == "secondary" or variant == "danger" or variant == "success",
		"invalid button variant")
	local sprite_name = "button_" .. variant .. (self.shape == "capsule" and "_capsule" or "")
	self.background = NineSliceUsage(Resources.nine_slices[sprite_name])
	self.hover_background = NineSliceUsage(Resources.nine_slices[sprite_name .. "_hover"])
	self.pressed_background = NineSliceUsage(Resources.nine_slices[sprite_name .. "_pressed"])
end

---@param e gui.MouseClickEvent
function Button:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	if self.on_click then
		self.on_click()
		self:scaleTo(1, 1, 0.12, "OutCubic")
	end
	return true
end

function Button:onMouseDown(e)
	if e.button == 1 then
		self:scaleTo(0.975, 0.975, 0.08, "OutQuad")
		return true
	end
end

function Button:onMouseUp(e)
	if e.button == 1 then
		self:scaleTo(1, 1, 0.12, "OutCubic")
		return true
	end
end

function Button:update(dt)
	self.hover:configure(self.mouse_over and HOVER_ENTER_SPRING or HOVER_EXIT_SPRING)
	self.hover:set(self.mouse_over and 1 or 0)
	self.hover:update(dt)
end

function Button:draw()
	local lg = love.graphics
	local ui_scale = assert(self.screen).ui_scale
	local hover = math.max(0, math.min(1, self.hover:get()))
	Painter.snapToPixel()
	if self.pressed then
		Painter.setColorRgb(1, 1, 1)
		self.pressed_background:draw(self.width, self.height)
	else
		Painter.setColorRgb(1, 1, 1)
		self.background:draw(self.width, self.height)
		if hover > 0.001 then
			Painter.setOpacity(hover)
			self.hover_background:draw(self.width, self.height)
		end
	end

	Painter.setOpacity(1)
	Painter.setColorTable(Colors.text)
	lg.setFont(self.font)
	local text_y = (self.height - self.font:getHeight()) / 2 + (self.pressed and 1 or 0)
	lg.printf(self.text, 0, text_y, self.width, "center")
end

return Button
