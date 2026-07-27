local code = [[
extern float u_thresholds[{{COUNT}}];
extern vec4 u_colors[{{COUNT}}];
extern float u_innerRadius;
extern float u_outerRadius;
extern float u_gapWidth;

const float PI = 3.14159265359;
const float AA_STRENGTH = 2.0;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords * 2.0 - 1.0;
    float dist = length(uv);
    float edgeSoftness = fwidth(dist) * AA_STRENGTH;

    float segmentRingMask = smoothstep(u_innerRadius - edgeSoftness, u_innerRadius, dist) *
                            (1.0 - smoothstep(u_outerRadius, u_outerRadius + edgeSoftness, dist));

    if (segmentRingMask == 0.0) {
        discard;
    }

    float angle = atan(-uv.x, -uv.y);
    if (angle < 0.0) angle += 2.0 * PI;
    float t = angle / (2.0 * PI);

    vec4 segmentColor = u_colors[0];

    for (int i = 0; i < {{COUNT_MINUS_ONE}}; i++) {
        if (t > u_thresholds[i]) {
            segmentColor = u_colors[i + 1];
        }
    }

    float tGap = u_gapWidth / (2.0 * PI);
    float gapMask = 1.0;
    for (int i = 0; i < {{COUNT}}; i++) {
        float diff = abs(t - u_thresholds[i]);
        if (diff > 0.5) diff = 1.0 - diff;
        float borderMask = smoothstep(0.0, fwidth(t) * AA_STRENGTH, diff - tGap);
        gapMask *= borderMask;
    }

    return vec4(segmentColor.rgb, segmentRingMask * gapMask * segmentColor.a) * color;
}
]]

---@param segments integer
---@return love.Shader
local function makeShader(segments)
	local shader_code = code:gsub("{{COUNT}}", segments):gsub("{{COUNT_MINUS_ONE}}", segments - 1)
	return love.graphics.newShader(shader_code)
end

return makeShader
