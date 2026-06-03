local View = require("ui.View")
local Colors = require("yi.Colors")

---@class yi.MainMenuWave : ui.View
---@operator call: yi.MainMenuWave
local MainMenuWave = View + {}

local wave_shader_code = [[
	extern float time;
	extern float wave_speed;
	extern float wave_height;
	extern float frequency;

	vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
		vec2 uv = texture_coords;
		float animated_time = time * wave_speed;
		float drift_x = uv.x - animated_time;

		float wave1 = sin(drift_x * frequency * 3.14159 + animated_time) * wave_height;
		float wave2 = sin((drift_x * 1.17 + 0.11) * frequency * 3.14159 + animated_time + 1.57) * wave_height * 0.7;
		float detail = sin((drift_x * 2.4 - 0.07) * frequency * 3.14159 - animated_time * 0.6) * wave_height * 0.22;

		float top_wave = 0.65 + wave1 + detail;
		float bottom_wave = 0.35 + wave2 - detail * 0.6;

		float dist_to_top = top_wave - uv.y;
		float dist_to_bottom = uv.y - bottom_wave;
		float inside = min(dist_to_top, dist_to_bottom);
		float alpha = smoothstep(0.0, 0.02, inside) * 0.8;
		return vec4(vec3(1.0), alpha) * color;
	}
]]

function MainMenuWave:new()
	View.new(self)
	self.wave_speed = 0.18
	self.wave_amplitude = 0.025
	self.wave_frequency = 2.1
	self.color = Colors.accent
	self.alpha = 0.42
	self.pixel = love.graphics.newCanvas(1, 1)
	self.shader = love.graphics.newShader(wave_shader_code)
	self.shader:send("wave_speed", self.wave_speed)
	self.shader:send("wave_height", self.wave_amplitude)
	self.shader:send("frequency", self.wave_frequency)
end

function MainMenuWave:draw()
	local shader = self.shader
	local pixel = self.pixel
	local color = self.color
	local lg = love.graphics

	lg.push("all")
	lg.setBlendMode("add")
	shader:send("time", love.timer.getTime())
	lg.setShader(shader)
	lg.setColor(color[1], color[2], color[3], self.alpha)
	lg.draw(pixel, 0, 0, 0, self.box.width, self.box.height)
	lg.setShader()
	lg.pop()
end

return MainMenuWave
