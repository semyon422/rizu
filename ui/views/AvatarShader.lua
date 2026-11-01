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

---Clips to a rounded rect given in the current local space. The shader works in pixels of the
---target being drawn to, which inside a composite canvas are not screen pixels, so it goes
---through the current transform rather than a view's world transform.
---@param shader love.Shader
---@param x number
---@param y number
---@param width number
---@param height number
---@param radius number
function AvatarShader.setRect(shader, x, y, width, height, radius)
	local x1, y1 = love.graphics.transformPoint(x, y)
	local x2, y2 = love.graphics.transformPoint(x + width, y + height)
	local scale = (x2 - x1) / width
	shader:send("u_position", {x1, y1})
	shader:send("u_size", {x2 - x1, y2 - y1})
	shader:send("u_radius", radius * scale)
end

return AvatarShader
