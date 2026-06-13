local code = [[
extern float u_thresholds[{{COUNT}}];
extern vec4 u_colors[{{COUNT}}];
extern float u_innerRadius;   
extern float u_outerRadius;   
extern float u_gapWidth;      
extern float u_bgOffset;      

const float PI = 3.14159265359;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords * 2.0 - 1.0;
    float dist = length(uv);
    float edgeSoftness = fwidth(dist);

    // 1. Calculate masks
    float segmentRingMask = smoothstep(u_innerRadius - edgeSoftness, u_innerRadius, dist) *
                            (1.0 - smoothstep(u_outerRadius, u_outerRadius + edgeSoftness, dist));
    
    float bgInner = u_innerRadius + u_bgOffset;
    float bgOuter = u_outerRadius - u_bgOffset;
    float bgRingMask = smoothstep(bgInner - edgeSoftness, bgInner, dist) *
                       (1.0 - smoothstep(bgOuter, bgOuter + edgeSoftness, dist));

    if (segmentRingMask == 0.0 && bgRingMask == 0.0) {
        discard;
    }

    // 2. Counter-clockwise math adjusting for Love2D's Y-down coordinate space
    float angle = atan(-uv.x, -uv.y);
    if (angle < 0.0) angle += 2.0 * PI;
    float t = angle / (2.0 * PI);

    // 3. Segment evaluation & Gradient Bounds Tracking
    vec4 segmentColor = u_colors[0];
    float segStart = 0.0;
    float segEnd = u_thresholds[0];

    for (int i = 0; i < {{COUNT_MINUS_ONE}}; i++) {
        if (t > u_thresholds[i]) {
            segmentColor = u_colors[i + 1];
            segStart = u_thresholds[i];
            segEnd = (i + 1 < {{COUNT_MINUS_ONE}}) ? u_thresholds[i + 1] : 1.0;
        }
    }

    // Calculate local t (0.0 at the start of the segment, 1.0 at the end)
    float localT = (t - segStart) / (segEnd - segStart);
    localT = clamp(localT, 0.0, 1.0);

    // Apply darkening factor (1.0 at start, fading down to 0.4 at the end)
    // Adjust 0.4 to whatever minimum brightness you prefer!
    float darkeningFactor = mix(1.0, 0.8, localT);
    segmentColor.rgb *= darkeningFactor;

    // 4. Gaps calculation
    float tGap = u_gapWidth / (2.0 * PI); 
    float gapMask = 1.0;
    for (int i = 0; i < {{COUNT}}; i++) {
        float diff = abs(t - u_thresholds[i]);
        if (diff > 0.5) diff = 1.0 - diff; 
        float borderMask = smoothstep(0.0, fwidth(t), diff - tGap);
        gapMask *= borderMask;
    }

    // 5. Blending layer rules
    vec4 bg = vec4(0.0, 0.0, 0.0, bgRingMask);
    vec4 fg = vec4(segmentColor.rgb, segmentRingMask * gapMask * segmentColor.a);

    // 6. Straight alpha composition
    float outAlpha = fg.a + bg.a * (1.0 - fg.a);
    vec3 outRgb = vec3(0.0);
    
    if (outAlpha > 0.0) {
        outRgb = (fg.rgb * fg.a + bg.rgb * bg.a * (1.0 - fg.a)) / outAlpha;
    }

    return vec4(outRgb, outAlpha) * color;
}
]]

---@param segments integer
---@return love.Shader
local function makeShader(segments)
	local c = code:gsub("{{COUNT}}", segments):gsub("{{COUNT_MINUS_ONE}}", segments - 1)
	return love.graphics.newShader(c)
end

return makeShader
