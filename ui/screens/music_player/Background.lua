local Background = require("ui.views.Background")

local lg = love.graphics

local shader_code = [[
	extern float elapsed;
	extern vec4 fft_low;
	extern vec4 fft_mid;
	extern vec4 fft_high;
	extern vec4 fft_air;

	vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
		float bass = (fft_low.x + fft_low.y + fft_low.z + fft_low.w) * 0.25;
		float mids = (fft_mid.x + fft_mid.y + fft_mid.z + fft_mid.w) * 0.25;
		float highs = (fft_high.x + fft_high.y + fft_high.z + fft_high.w) * 0.25;
		float air = (fft_air.x + fft_air.y + fft_air.z + fft_air.w) * 0.25;

		vec2 center = texture_coords - 0.5;
		float radius = length(center);
		vec2 direction = center / max(radius, 0.001);

		// Bass gently pumps the image without warping it.
		vec2 uv = clamp(0.5 + center * (1.0 - bass * 0.045), vec2(0.002), vec2(0.998));

		// High frequencies split the color channels away from the center.
		vec2 split = direction * (0.001 + highs * 0.009 + air * 0.004);
		float red = Texel(texture, clamp(uv + split, vec2(0.002), vec2(0.998))).r;
		float green = Texel(texture, uv).g;
		float blue = Texel(texture, clamp(uv - split, vec2(0.002), vec2(0.998))).b;
		vec4 pixel = vec4(red, green, blue, Texel(texture, uv).a);

		float moving_glow = 0.5 + 0.5 * sin(radius * 24.0 - elapsed * 2.5);
		vec3 tint = vec3(0.12, 0.035, 0.18) * (mids * 0.8 + highs * moving_glow);
		pixel.rgb += tint;
		pixel.rgb *= 0.88 + bass * 0.42;

		float vignette = smoothstep(0.78, 0.22, radius);
		pixel.rgb *= 0.58 + vignette * 0.42;
		return pixel * color;
	}
]]

---@class ui.screens.music_player.Background : ui.views.Background
---@operator call: ui.screens.music_player.Background
---@field preview_model rizu.preview.PreviewModel
---@field fft_size integer
---@field shader love.Shader?
---@field elapsed number
---@field bands number[]
local MusicBackground = Background + {}

---@param model sphere.BackgroundModel
---@param preview_model rizu.preview.PreviewModel
---@param fft_size integer
function MusicBackground:new(model, preview_model, fft_size)
	Background.new(self, model)
	self.preview_model = preview_model
	self.fft_size = fft_size
	self.elapsed = 0
	---@type number[]
	self.bands = {}
	for i = 1, 16 do
		self.bands[i] = 0
	end
end

function MusicBackground:load()
	self.shader = lg.newShader(shader_code)
end

function MusicBackground:unload()
	if self.shader then
		self.shader:release()
		self.shader = nil
	end
end

---@param dt number
function MusicBackground:update(dt)
	Background.update(self, dt)
	self.elapsed = self.elapsed + dt
	local fft = self.preview_model:getFFT()
	local bin_count = self.fft_size / 2 - 1
	local bucket_space = bin_count - 16
	for i = 1, 16 do
		local value = 0
		if fft then
			local first = i + math.floor(bucket_space * ((i - 1) / 16) ^ 2)
			local last = i + math.floor(bucket_space * (i / 16) ^ 2)
			for bin = first, last do
				value = math.max(value, fft[bin])
			end
			value = math.min(math.sqrt(value) * 1.8, 1)
		end
		if value > self.bands[i] then
			self.bands[i] = value
		else
			local decay = 1 - math.exp(-4 * dt)
			self.bands[i] = self.bands[i] + (value - self.bands[i]) * decay
		end
	end
end

---@param first integer
---@return number[]
function MusicBackground:getBandVector(first)
	return {self.bands[first], self.bands[first + 1], self.bands[first + 2], self.bands[first + 3]}
end

function MusicBackground:draw()
	local shader = self.shader
	if shader then
		shader:send("elapsed", self.elapsed)
		shader:send("fft_low", self:getBandVector(1))
		shader:send("fft_mid", self:getBandVector(5))
		shader:send("fft_high", self:getBandVector(9))
		shader:send("fft_air", self:getBandVector(13))
		lg.setShader(shader)
	end
	Background.draw(self)
	lg.setShader()
end

return MusicBackground
