local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")

local lg = love.graphics

---The big slanted Play button: the play_button sprite (resources/yi/src/play_button.svg)
---with a dot grid drifting diagonally over it.
---@class ui.screens.main_menu_v2.PlayButton : gui.View
---@operator call: ui.screens.main_menu_v2.PlayButton
---@field on_click fun()
---@field mesh love.Mesh? The sprite's slanted shape, for the dots
---@field dots_offset number
local PlayButton = View + {}

local SLANT = 40 -- matches the svg
local DOTS_SPACING = 18
local DOTS_SPEED = 12 -- logical pixels per second along each axis

-- Mesh texture coordinates are logical pixels, so the dots keep their size on any button.
local shader_code = ([[
extern float u_offset;

const float SPACING = %.1f;
const float RADIUS = 2.25;
const float DOT_OPACITY = 0.14;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
	float d = length(mod(uv - vec2(u_offset, -u_offset), SPACING) - SPACING * 0.5);
	float aa = fwidth(d);
	float dot = 1.0 - smoothstep(RADIUS - aa, RADIUS + aa, d);
	return vec4(color.rgb, color.a * dot * DOT_OPACITY);
}
]]):format(DOTS_SPACING)

---@type love.Shader?
local shader

---@param text string
---@param on_click fun()
function PlayButton:new(text, on_click)
	View.new(self)
	self.on_click = on_click
	self.dots_offset = 0
	self.handles_mouse_input = true
	self:setPivot(0.5, 0.5)

	local label = self:add(Label({font_name = "bold", font_size = 88, text = text}))
	label:setAlignment(0, 0.5):addPosition(84, 0)
	local arrow = self:add(Image(Resources.sprites.icon_play, "fit"))
	arrow:setSize(56, 56):setAlignment(1, 0.5):addPosition(-44, 0)
end

function PlayButton:onLayoutChanged()
	if self.mesh then self.mesh:release() end
	local w, h = self.width, self.height
	self.mesh = lg.newMesh({
		{SLANT, 0, SLANT, 0},
		{w, 0, w, 0},
		{w, h, w, h},
		{0, h, 0, h},
	}, "fan", "static")
end

function PlayButton:unload()
	if self.mesh then
		self.mesh:release()
		self.mesh = nil
	end
end

---@param e gui.MouseDownEvent
function PlayButton:onMouseDown(e)
	if e.button ~= 1 then return end
	self:scaleTo(0.975, 0.975, 0.08, "OutQuad")
	return true
end

---@param e gui.MouseUpEvent
function PlayButton:onMouseUp(e)
	if e.button ~= 1 then return end
	self:scaleTo(1, 1, 0.12, "OutCubic")
	return true
end

---@param e gui.MouseClickEvent
function PlayButton:onMouseClick(e)
	if e.button ~= 1 then return end
	-- Leaving the screen drops the press, so onMouseUp may never come.
	self:scaleTo(1, 1, 0.12, "OutCubic")
	self.on_click()
	return true
end

---@param dt number
function PlayButton:update(dt)
	-- Wraps at the dot spacing so the offset stays small.
	self.dots_offset = (self.dots_offset + DOTS_SPEED * dt) % DOTS_SPACING
end

function PlayButton:draw()
	shader = shader or lg.newShader(shader_code)
	Painter.setColorRgb(1, 1, 1)
	local sprite = Resources.sprites.play_button
	local sw, sh = sprite:getDimensions()
	sprite:draw(0, 0, 0, self.width / sw, self.height / sh)
	local previous = lg.getShader()
	shader:send("u_offset", self.dots_offset)
	lg.setShader(shader)
	lg.draw(assert(self.mesh))
	lg.setShader(previous)
end

return PlayButton
