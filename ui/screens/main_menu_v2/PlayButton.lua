local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")
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
---@field pulse ui.views.Image Copy of the icon that grows and fades on each beat
---@field get_beat_phase fun(): number?
---@field get_bpm fun(): number?
---@field pulse_phase number
local PlayButton = View + {}

local SLANT = 40 -- matches the svg
local DOTS_SPACING = 18
local DOTS_SPEED = 12 -- logical pixels per second along each axis
local ICON_SIZE = 96
local PULSE_SCALE = 1.4
local DEFAULT_PULSE_DURATION = 1

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
---@param get_beat_phase (fun(): number?)? Beat of the playing music, nil when unknown
---@param get_bpm (fun(): number?)? Pulse rate when the beat is unknown
function PlayButton:new(text, on_click, get_beat_phase, get_bpm)
	View.new(self)
	self.on_click = on_click
	self.get_beat_phase = get_beat_phase or function() return nil end
	self.get_bpm = get_bpm or function() return nil end
	self.pulse_phase = 0
	self.dots_offset = 0
	self.handles_mouse_input = true
	self:setPivot(0.5, 0.5)

	local label = self:add(Label({font_name = "bold", font_size = 88, text = text}))
	label:setAlignment(0, 0.5):addPosition(84, 0)
	for i = 1, 2 do
		local icon = self:add(Image(Resources.sprites.icon_circle_play, "fit"))
		icon:setSize(ICON_SIZE, ICON_SIZE):setAlignment(1, 0.5):addPosition(-36, 0):setPivot(0.5, 0.5)
		self.pulse = icon
	end
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

---@param e gui.HoverEvent
function PlayButton:onHover(e)
	Sounds.play("hover")
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

	-- Same pulse as the v1 Play button: follows the music's beat, else the chart's bpm.
	local beat_phase = self.get_beat_phase()
	if beat_phase ~= nil then
		self.pulse_phase = beat_phase % 1
	else
		local bpm = self.get_bpm()
		local duration = bpm and bpm > 0 and bpm < math.huge and 60 / bpm or DEFAULT_PULSE_DURATION
		self.pulse_phase = (self.pulse_phase + dt / duration) % 1
	end
	local scale = 1 + (PULSE_SCALE - 1) * self.pulse_phase
	self.pulse:setScale(scale, scale):setOpacity(1 - self.pulse_phase)
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
