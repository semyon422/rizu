local code_outline = [[
extern float u_thickness;
extern float u_outline;
extern vec4 u_outline_color;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    float distance = Texel(texture, texture_coords).r;
    float smoothing = fwidth(distance) * 0.7071;
    
    float alpha = smoothstep(u_thickness - smoothing, u_thickness + smoothing, distance);
    
    float outline_thickness = u_thickness - u_outline;
    float outline_alpha = smoothstep(outline_thickness - smoothing, outline_thickness + smoothing, distance);
    
    vec4 base_color = vec4(color.rgb, color.a * alpha);
    vec4 outline_color_val = vec4(u_outline_color.rgb, color.a * u_outline_color.a * outline_alpha);
    
    // Pre-multiply and blend
    float out_a = base_color.a + outline_color_val.a * (1.0 - base_color.a);
    vec3 out_rgb = vec3(0.0);
    if (out_a > 0.0) {
        out_rgb = (base_color.rgb * base_color.a + outline_color_val.rgb * outline_color_val.a * (1.0 - base_color.a)) / out_a;
    }
    
    return vec4(out_rgb, out_a);
}
]]

---@return love.Shader
local function makeShader()
	local shader_outline = love.graphics.newShader(code_outline)
	return shader_outline
end

return makeShader
