local class = require("class")
local SliderMesh = require("rizu.gameplay.views.aim.SliderMesh")

local vertex_shader = [[
attribute vec2 SegmentStart;
attribute vec2 SegmentEnd;
attribute vec2 SegmentProgress;

varying vec2 path_position;
varying vec2 path_start;
varying vec2 path_end;
varying vec2 path_progress;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
	path_position = VertexPosition.xy;
	path_start = SegmentStart;
	path_end = SegmentEnd;
	path_progress = SegmentProgress;
	return transform_projection * vertex_position;
}
]]

local fragment_shader = [[
extern vec4 body_color;
extern vec4 border_color;
extern float opacity;
extern float path_radius;
extern vec2 snake_range;

varying vec2 path_position;
varying vec2 path_start;
varying vec2 path_end;
varying vec2 path_progress;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	float progress_length = path_progress.y - path_progress.x;
	float clipped_start_progress = max(path_progress.x, snake_range.x);
	float clipped_end_progress = min(path_progress.y, snake_range.y);
	if (clipped_start_progress > clipped_end_progress) discard;
	float local_start = progress_length > 0.0 ? clamp((clipped_start_progress - path_progress.x) / progress_length, 0.0, 1.0) : 0.0;
	float local_end = progress_length > 0.0 ? clamp((clipped_end_progress - path_progress.x) / progress_length, 0.0, 1.0) : 1.0;
	vec2 clipped_start = path_start + (path_end - path_start) * local_start;
	vec2 clipped_end = path_start + (path_end - path_start) * local_end;
	vec2 segment = clipped_end - clipped_start;
	float squared_length = dot(segment, segment);
	float segment_progress = squared_length > 0.0 ? clamp(dot(path_position - clipped_start, segment) / squared_length, 0.0, 1.0) : 0.0;
	float radial = distance(path_position, clipped_start + segment * segment_progress) / path_radius;
	if (radial > 1.0) discard;
	// Keep the fragment nearest the path centreline. Overlapping capsule quads
	// need this depth value; otherwise alpha blending exposes every segment.
	gl_FragDepth = radial * 0.9 + 0.1;
	float track_position = 1.0 - radial;
	float aa = max(fwidth(track_position), 1.0 / 256.0);
	vec4 shadow = vec4(0.0, 0.0, 0.0, 64.0 / 255.0);
	vec3 outer_rgb = body_color.rgb / 1.1;
	vec3 inner_rgb = min(vec3(1.0), body_color.rgb * 1.125 + vec3(0.25));
	vec4 outer = vec4(outer_rgb, 180.0 / 255.0 * body_color.a);
	vec4 inner = vec4(inner_rgb, 180.0 / 255.0 * body_color.a);
	vec4 tint;
	if (track_position < 0.078125 - aa) tint = shadow * smoothstep(0.0, 0.078125 - aa, track_position);
	else if (track_position < 0.078125 + aa) tint = mix(shadow, border_color, smoothstep(0.078125 - aa, 0.078125 + aa, track_position));
	else if (track_position < 0.1875 - aa) tint = border_color;
	else if (track_position < 0.1875 + aa) tint = mix(border_color, outer, smoothstep(0.1875 - aa, 0.1875 + aa, track_position));
	else tint = mix(outer, inner, (track_position - 0.1875) / 0.8125);
	return vec4(tint.rgb, tint.a * opacity) * color;
}
]]

---@class rizu.gameplay.views.aim.SliderGraphics
---@operator call: rizu.gameplay.views.aim.SliderGraphics
local SliderGraphics = class()

function SliderGraphics:new()
	self.meshes = {}
end

---@param rules rizu.aim.CircleRules
function SliderGraphics:prepare(rules)
	self:unload()
	self.radius = rules.radius
	self.shader = love.graphics.newShader(vertex_shader, fragment_shader)
	for index, slider in pairs(rules.sliders) do self.meshes[index] = SliderMesh.create(slider.path, rules.radius) end
end

function SliderGraphics:unload()
	self.shader = nil
	self.meshes = {}
end

---@param index integer
---@param alpha number
---@param snake_start number
---@param snake_end number
function SliderGraphics:draw(index, alpha, snake_start, snake_end)
	local mesh = self.meshes[index]
	if not mesh or alpha <= 0 then return end
	self.shader:send("body_color", {0.16, 0.33, 0.46, 1})
	self.shader:send("border_color", {0.85, 0.95, 1, 1})
	self.shader:send("opacity", alpha)
	self.shader:send("path_radius", self.radius)
	self.shader:send("snake_range", {math.min(snake_start, snake_end), math.max(snake_start, snake_end)})
	-- The fragment shader multiplies its result by the current draw colour.
	-- Slider rendering must not inherit a prior object's tint or opacity.
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setShader(self.shader)
	-- The mesh is a collection of overlapping capsule bounds. Match the web
	-- renderer's depth prepass so only the fragment nearest the centreline is
	-- blended; ordinary alpha blending makes curved paths look segmented.
	love.graphics.clear({depth = 1})
	love.graphics.setColorMask(false, false, false, false)
	love.graphics.setDepthMode("lequal", true)
	love.graphics.draw(mesh)
	love.graphics.setColorMask(true, true, true, true)
	love.graphics.setDepthMode("equal", false)
	love.graphics.draw(mesh)
	love.graphics.setDepthMode("always", false)
	love.graphics.setShader()
end

return SliderGraphics
