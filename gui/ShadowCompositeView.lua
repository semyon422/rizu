local CompositeView = require("gui.CompositeView")

---@class gui.ShadowCompositeView.Config
---@field blur? number Gaussian sigma in logical pixels.
---@field offset_x? number Logical pixels.
---@field offset_y? number Logical pixels.
---@field opacity? number Shadow strength, 0..1.

---A CompositeView that draws a soft shadow under its content: the alpha of the whole content canvas,
---turned black and blurred. It covers text, sprites and everything else the same way.
---@class gui.ShadowCompositeView : gui.CompositeView
---@operator call: gui.ShadowCompositeView
---@field blur number
---@field offset_x number
---@field offset_y number
---@field shadow_opacity number
---@field shadow_canvas love.Canvas? Final blurred shadow, at `downscale` of the content canvas size.
---@field scratch_canvas love.Canvas? Horizontal pass output.
local ShadowCompositeView = CompositeView + {}

-- The blur runs on a reduced canvas; the shadow is soft anyway.
local DOWNSCALE = 0.5
local TAPS = 8
local SIGMA_TAPS = 3

local shader_code = ([[
extern vec2 u_step;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
	float sum = 0.0;
	float weights = 0.0;
	for (int i = -%d; i <= %d; i++) {
		float x = float(i);
		float w = exp(-x * x / (2.0 * %f * %f));
		sum += Texel(tex, uv + u_step * x).a * w;
		weights += w;
	}
	return vec4(0.0, 0.0, 0.0, sum / weights);
}
]]):format(TAPS, TAPS, SIGMA_TAPS, SIGMA_TAPS)

---@type love.Shader?
local shader

---@param config gui.ShadowCompositeView.Config?
function ShadowCompositeView:new(config)
	CompositeView.new(self)
	config = config or {}
	self.blur = config.blur or 6
	self.offset_x = config.offset_x or 0
	self.offset_y = config.offset_y or 3
	self.shadow_opacity = config.opacity or 0.8
end

---@param old_x number
---@param old_y number
---@param old_width number
---@param old_height number
function ShadowCompositeView:onLayoutChanged(old_x, old_y, old_width, old_height)
	CompositeView.onLayoutChanged(self, old_x, old_y, old_width, old_height)
	self:releaseShadowCanvases()

	local canvas = self.canvas
	if not canvas then
		return
	end
	local width = math.max(1, math.ceil(canvas:getWidth() * DOWNSCALE))
	local height = math.max(1, math.ceil(canvas:getHeight() * DOWNSCALE))
	self.scratch_canvas = love.graphics.newCanvas(width, height)
	self.shadow_canvas = love.graphics.newCanvas(width, height)
end

---@private
function ShadowCompositeView:releaseShadowCanvases()
	if self.scratch_canvas then
		self.scratch_canvas:release()
		self.scratch_canvas = nil
	end
	if self.shadow_canvas then
		self.shadow_canvas:release()
		self.shadow_canvas = nil
	end
end

function ShadowCompositeView:unload()
	self:releaseShadowCanvases()
	CompositeView.unload(self)
end

---Blurs the content canvas alpha into `shadow_canvas`. Called by the Renderer once the content is drawn.
---@param restore_canvas love.Canvas? Canvas to make current again afterwards.
function ShadowCompositeView:postProcess(restore_canvas)
	local content = self.canvas
	local scratch = self.scratch_canvas
	local target = self.shadow_canvas
	if not (content and scratch and target) then
		return
	end

	shader = shader or love.graphics.newShader(shader_code)
	local lg = love.graphics
	local sigma = self.blur * self.canvas_scale -- in content pixels
	local content_width = content:getWidth()
	local scratch_width, scratch_height = scratch:getDimensions()

	lg.origin()
	lg.setScissor()
	lg.setShader(shader)
	lg.setBlendMode("replace")
	lg.setColor(1, 1, 1, 1)

	-- Horizontal pass: content (full size) -> scratch (reduced). Steps are measured in content pixels.
	shader:send("u_step", {sigma / SIGMA_TAPS / content_width, 0})
	lg.setCanvas(scratch)
	lg.clear(0, 0, 0, 0)
	lg.draw(content, 0, 0, 0, scratch_width / content_width, scratch_height / content:getHeight())

	-- Vertical pass: scratch -> shadow, at the reduced size. Steps are measured in reduced pixels.
	shader:send("u_step", {0, sigma * DOWNSCALE / SIGMA_TAPS / scratch_height})
	lg.setCanvas(target)
	lg.clear(0, 0, 0, 0)
	lg.draw(scratch)

	lg.setShader()
	lg.setBlendMode("alpha")
	if restore_canvas then
		lg.setCanvas(restore_canvas)
	else
		lg.setCanvas()
	end
end

---Draws the prepared shadow in this view's local logical space. Called before the content is drawn.
---@param opacity number The view's render opacity.
function ShadowCompositeView:drawUnderlay(opacity)
	local shadow = self.shadow_canvas
	if not shadow then
		return
	end
	local alpha = opacity * self.shadow_opacity
	love.graphics.setColor(alpha, alpha, alpha, alpha)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(
		shadow,
		self.offset_x,
		self.offset_y,
		0,
		self.width / shadow:getWidth(),
		self.height / shadow:getHeight()
	)
end

return ShadowCompositeView
