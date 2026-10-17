local shader_code = [[
extern vec2 u_position;
extern vec2 u_size;
extern number u_radius;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	vec2 p = screen_coords - u_position - u_size * 0.5;
	vec2 half_size = u_size * 0.5 - vec2(u_radius);
	float distance_to_corner = length(max(abs(p) - half_size, vec2(0.0))) - u_radius;
	float alpha = 1.0 - smoothstep(0.0, 1.0, distance_to_corner);
	return Texel(texture, texture_coords) * color * alpha;
}
]]

---@class ui.views.AvatarShader
local AvatarShader = {}

---@return love.Shader
function AvatarShader.new()
	return love.graphics.newShader(shader_code)
end

return AvatarShader
