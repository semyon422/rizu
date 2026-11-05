local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

local lg = love.graphics

---The dan estimated by Rizu Difficulty: the REFORM dan's icon, with a small plus or minus mark.
---Dans without an icon in resources/yi/batch are written out.
---From Gamma up the icon glitches now and then, more the higher the dan.
---@class ui.screens.song_select_v2.DanBadge : gui.View
---@operator call: ui.screens.song_select_v2.DanBadge
---@field name string?
---@field mark "+"|"-"?
---@field icon gui.Sprite?
---@field mark_icon gui.Sprite?
---@field font love.Font
---@field intensity number 0 (never glitches) to 1
---@field next_glitch number Seconds until the next glitch
---@field glitch_left number Seconds the running glitch lasts, 0 when none
---@field glitch_time number
local DanBadge = View + {}

DanBadge.HEIGHT = 56
local GAP = 6

-- Seconds between two glitches, and how long one lasts at intensity 1 (shorter below).
local GLITCH_GAP_MIN, GLITCH_GAP_MAX = 1, 3
local GLITCH_LENGTH = 0.3

local GLITCH_RANKS = {"gamma", "delta", "epsilon", "zeta", "eta", "theta"}

local shader ---@type love.Shader?

local SHADER_CODE = [[
uniform float intensity;
uniform float time;
uniform vec4 bounds; // the sprite's rect in the atlas, in uv

float hash(float n) { return fract(sin(n * 91.345) * 47453.5453); }

// p is in the sprite, 0..1; nothing outside of it, so a shifted row does not read the neighbors in the atlas
vec4 sprite(Image tex, vec2 p) {
	if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) return vec4(0.0);
	return Texel(tex, bounds.xy + p * (bounds.zw - bounds.xy));
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
	vec2 p = (uv - bounds.xy) / (bounds.zw - bounds.xy);
	float tick = floor(time * 24.0);
	float band = floor(p.y * 14.0);
	float moved = step(1.0 - 0.5 * intensity, hash(band + tick * 7.0));
	float shift = (hash(band * 3.1 + tick) - 0.5) * 0.6 * intensity * moved;
	float split = 0.05 * intensity * (0.4 + moved);
	vec4 r = sprite(tex, vec2(p.x + shift + split, p.y));
	vec4 g = sprite(tex, vec2(p.x + shift, p.y));
	vec4 b = sprite(tex, vec2(p.x + shift - split, p.y));
	return vec4(r.r, g.g, b.b, max(max(r.a, g.a), b.a)) * color;
}
]]

---How hard a dan glitches: 0 below Gamma, 0.2 at Gamma, 1 at Theta.
---@param name string The dan's name, "Beta"
---@return number
function DanBadge.glitchIntensity(name)
	name = name:lower()
	for i, rank in ipairs(GLITCH_RANKS) do
		if name == rank then
			return 0.2 + 0.8 * (i - 1) / (#GLITCH_RANKS - 1)
		end
	end
	return 0
end

---The rect of a sprite in its atlas, in uv.
---@param sprite gui.AtlasImage
---@return number[]
local function getBounds(sprite)
	local x, y, w, h = sprite.quad:getViewport()
	local aw, ah = sprite.atlas:getDimensions()
	return {x / aw, y / ah, (x + w) / aw, (y + h) / ah}
end

---Splits a RizuDifficulty.dan() result, "Beta+" into "Beta" and "+".
---@param dan string
---@return string name
---@return "+"|"-"|nil mark
function DanBadge.parse(dan)
	local name, mark = dan:match("^(.-)([+-]?)$")
	return name, mark ~= "" and mark or nil
end

---The image name of a dan name: "dan_4k_reform_9" for "9th", "dan_4k_reform_beta" for "Beta".
---@param name string
---@return string
function DanBadge.imageName(name)
	return "dan_4k_reform_" .. (name:match("^(%d+)") or name:lower())
end

function DanBadge:new()
	View.new(self)
	self.font = Resources.getFont("bold", 34)
	self.intensity = 0
	self.next_glitch = 0
	self.glitch_left = 0
	self.glitch_time = 0
	self:setSize(0, DanBadge.HEIGHT)
	self:setVisible(false)
end

---@param dt number
function DanBadge:update(dt)
	if self.intensity == 0 then return end
	if self.glitch_left > 0 then
		self.glitch_left = self.glitch_left - dt
		self.glitch_time = self.glitch_time + dt
		if self.glitch_left <= 0 then
			self.glitch_left = 0
			self.next_glitch = GLITCH_GAP_MIN + math.random() * (GLITCH_GAP_MAX - GLITCH_GAP_MIN)
		end
		return
	end
	self.next_glitch = self.next_glitch - dt
	if self.next_glitch <= 0 then
		self.glitch_left = GLITCH_LENGTH * (0.3 + 0.7 * self.intensity) * (0.5 + 0.5 * math.random())
		self.glitch_time = math.random() * 100
	end
end

---@param dan string? Nil hides the badge.
function DanBadge:setDan(dan)
	self:setVisible(dan ~= nil)
	if not dan then return end
	self.name, self.mark = DanBadge.parse(dan)
	local intensity = DanBadge.glitchIntensity(self.name)
	if intensity ~= self.intensity then
		self.intensity = intensity
		self.glitch_left = 0
		self.next_glitch = GLITCH_GAP_MIN + math.random() * (GLITCH_GAP_MAX - GLITCH_GAP_MIN)
	end
	local sprites = Resources.sprites
	-- The sprites table raises on a missing key.
	self.icon = rawget(sprites, DanBadge.imageName(self.name))
	self.mark_icon = self.mark and rawget(sprites, self.mark == "+" and "dan_plus" or "dan_minus") or nil

	local scale = self.icon and DanBadge.HEIGHT / self.icon:getHeight() or 1
	local width
	if self.icon then
		width = self.icon:getWidth() * scale
		if self.mark_icon then width = width + GAP + self.mark_icon:getWidth() * scale end
	else
		width = self.font:getWidth(dan)
	end
	self:setSize(math.ceil(width), DanBadge.HEIGHT)
end

function DanBadge:draw()
	Painter.setColorRgb(1, 1, 1)
	if not self.icon then
		lg.setFont(self.font)
		Painter.setColorTable(Colors.text)
		lg.print(self.name .. (self.mark or ""), 0, (self.height - self.font:getHeight()) / 2)
		Painter.setColorRgb(1, 1, 1)
		return
	end
	local glitching = self.glitch_left > 0
	if glitching then
		shader = shader or lg.newShader(SHADER_CODE)
		shader:send("intensity", self.intensity)
		shader:send("time", self.glitch_time)
		lg.setShader(shader)
		shader:send("bounds", getBounds(self.icon))
	end
	local scale = self.height / self.icon:getHeight()
	self.icon:draw(0, 0, 0, scale, scale)
	if self.mark_icon then
		if glitching then shader:send("bounds", getBounds(self.mark_icon)) end
		local x = self.icon:getWidth() * scale + GAP
		self.mark_icon:draw(x, (self.height - self.mark_icon:getHeight() * scale) / 2, 0, scale, scale)
	end
	if glitching then lg.setShader() end
end

return DanBadge
