local View = require("gui.View")
local Painter = require("gui.Painter")

local lg = love.graphics

---Shows the model's background blurred until it is only colour. The dual Kawase blur runs one
---pass per frame, so a chart change never costs more than one small draw in any frame. Two
---blurred images are kept at most: the shown one and the one fading in over it.
---@class ui.views.BlurredBackground : gui.View
---@operator call: ui.views.BlurredBackground
---@field media rizu.api.Media
---@field observer util.Observer?
---@field chain love.Canvas[]? Blur levels, each half the size of the previous one.
---@field shown love.Canvas? Finished blur under the fade.
---@field incoming love.Canvas? Blur target, then the image fading in.
---@field has_shown boolean
---@field pending love.Image? Latest image waiting for a blur.
---@field source love.Image? Image of the running blur.
---@field step integer Next blur pass, 0-based.
---@field fade number? 0..1 while `incoming` fades in.
local BlurredBackground = View + {}

-- The blur works on a small fixed canvas: it is cheap, and the result is stretched anyway.
local BASE_WIDTH = 480
local BASE_HEIGHT = 270
-- 5 halvings from 270 rows are about a 70px blur on a 1080p screen.
local ITERATIONS = 5
local FADE_DURATION = 0.5

local down_code = [[
extern vec2 u_half;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
	vec4 sum = Texel(tex, uv) * 4.0;
	sum += Texel(tex, uv - u_half);
	sum += Texel(tex, uv + u_half);
	sum += Texel(tex, uv + vec2(u_half.x, -u_half.y));
	sum += Texel(tex, uv - vec2(u_half.x, -u_half.y));
	return sum / 8.0;
}
]]

local up_code = [[
extern vec2 u_half;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
	vec4 sum = Texel(tex, uv + vec2(-u_half.x * 2.0, 0.0));
	sum += Texel(tex, uv + vec2(-u_half.x, u_half.y)) * 2.0;
	sum += Texel(tex, uv + vec2(0.0, u_half.y * 2.0));
	sum += Texel(tex, uv + vec2(u_half.x, u_half.y)) * 2.0;
	sum += Texel(tex, uv + vec2(u_half.x * 2.0, 0.0));
	sum += Texel(tex, uv + vec2(u_half.x, -u_half.y)) * 2.0;
	sum += Texel(tex, uv + vec2(0.0, -u_half.y * 2.0));
	sum += Texel(tex, uv + vec2(-u_half.x, -u_half.y)) * 2.0;
	return sum / 12.0;
}
]]

---@type love.Shader?, love.Shader?
local down_shader, up_shader

---@param media rizu.api.Media
function BlurredBackground:new(media)
	View.new(self)
	self.media = media
	self.has_shown = false
	self.step = 0
end

function BlurredBackground:load()
	down_shader = down_shader or lg.newShader(down_code)
	up_shader = up_shader or lg.newShader(up_code)

	self.chain = {}
	local width, height = BASE_WIDTH, BASE_HEIGHT
	for i = 0, ITERATIONS do
		self.chain[i] = lg.newCanvas(width, height, {dpiscale = 1})
		width, height = math.ceil(width / 2), math.ceil(height / 2)
	end
	self.shown = lg.newCanvas(BASE_WIDTH, BASE_HEIGHT, {dpiscale = 1})
	self.incoming = lg.newCanvas(BASE_WIDTH, BASE_HEIGHT, {dpiscale = 1})

	local images = self.media:getBackgroundImages()
	self.pending = images[#images]
	self.unsubscribe = self.media:on("background_changed", function(image)
		self.pending = image
	end)
end

function BlurredBackground:unload()
	if self.unsubscribe then
		self.unsubscribe()
		self.unsubscribe = nil
	end
	if self.chain then
		for i = 0, ITERATIONS do
			self.chain[i]:release()
		end
		self.shown:release()
		self.incoming:release()
	end
	self.chain, self.shown, self.incoming = nil, nil, nil
	self.pending, self.source, self.fade = nil, nil, nil
	self.has_shown = false
	self.step = 0
end

---Runs one pass of the running blur. Returns true when `incoming` holds the finished image.
---@private
---@return boolean finished
function BlurredBackground:blurStep()
	local chain = assert(self.chain)
	local step = self.step
	self.step = step + 1

	lg.push("all")
	lg.origin()
	lg.setBlendMode("replace")
	lg.setColor(1, 1, 1, 1)
	if step == 0 then
		local image = assert(self.source)
		local image_width, image_height = image:getDimensions()
		local scale = math.max(BASE_WIDTH / image_width, BASE_HEIGHT / image_height)
		lg.setCanvas(chain[0])
		lg.draw(image, BASE_WIDTH / 2, BASE_HEIGHT / 2, 0, scale, scale, image_width / 2, image_height / 2)
	else
		local down = step <= ITERATIONS
		-- Down passes go 0 -> ITERATIONS, up passes come back; `small` is the lower-resolution side.
		local small = down and step or 2 * ITERATIONS - step + 1
		local shader = assert(down and down_shader or up_shader)
		local from = down and chain[small - 1] or chain[small]
		local to = down and chain[small] or chain[small - 1]
		if step == 2 * ITERATIONS then
			to = assert(self.incoming)
		end
		shader:send("u_half", {0.5 / chain[small]:getWidth(), 0.5 / chain[small]:getHeight()})
		lg.setShader(shader)
		lg.setCanvas(to)
		lg.draw(from, 0, 0, 0, to:getWidth() / from:getWidth(), to:getHeight() / from:getHeight())
	end
	lg.pop()

	return step == 2 * ITERATIONS
end

---@param dt number
function BlurredBackground:update(dt)
	if not self.chain then
		return
	end

	if self.fade then
		self.fade = self.fade + dt / FADE_DURATION
		if self.fade < 1 then
			return
		end
		self.shown, self.incoming = self.incoming, self.shown
		self.has_shown = true
		self.fade = nil
	end

	-- `incoming` is free here. A newer image restarts the blur: the old one would never be shown.
	if self.pending then
		self.source = self.pending
		self.pending = nil
		self.step = 0
	end
	if self.source and self:blurStep() then
		self.source = nil
		self.fade = 0
	end
end

---@private
---@param canvas love.Canvas
---@param alpha number
function BlurredBackground:drawCover(canvas, alpha)
	local scale = math.max(self.width / BASE_WIDTH, self.height / BASE_HEIGHT)
	Painter.setColorRgb(1, 1, 1, alpha)
	lg.draw(canvas, self.width / 2, self.height / 2, 0, scale, scale, BASE_WIDTH / 2, BASE_HEIGHT / 2)
end

function BlurredBackground:draw()
	if self.has_shown then
		self:drawCover(assert(self.shown), 1)
	end
	if self.fade then
		local fade = self.fade
		-- Smoothstep: a linear crossfade starts and stops abruptly.
		self:drawCover(assert(self.incoming), fade * fade * (3 - 2 * fade))
	end
end

return BlurredBackground
