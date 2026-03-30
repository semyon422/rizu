local Color = {}

---@param value number
---@return number
local function clamp01(value)
	if value < 0 then
		return 0
	end
	if value > 1 then
		return 1
	end
	return value
end

---@param out ui.Color
---@param r number
---@param g number
---@param b number
---@param a number
---@return ui.Color
function Color.set(out, r, g, b, a)
	out[1], out[2], out[3], out[4] = r, g, b, a
	return out
end

---@param out ui.Color
---@param source ui.Color
---@return ui.Color
function Color.copy_to(out, source)
	out[1] = source[1]
	out[2] = source[2]
	out[3] = source[3]
	out[4] = source[4] or 1
	return out
end

---@param out ui.Color
---@param source ui.Color
---@param rgb_scale number
---@param alpha_scale number
---@return ui.Color
function Color.scale_to(out, source, rgb_scale, alpha_scale)
	out[1] = clamp01(source[1] * rgb_scale)
	out[2] = clamp01(source[2] * rgb_scale)
	out[3] = clamp01(source[3] * rgb_scale)
	out[4] = (source[4] or 1) * alpha_scale
	return out
end

---@param out ui.Color
---@param source ui.Color
---@param alpha_scale number
---@return ui.Color
function Color.scale_alpha_to(out, source, alpha_scale)
	out[1] = source[1]
	out[2] = source[2]
	out[3] = source[3]
	out[4] = (source[4] or 1) * alpha_scale
	return out
end

---@param out ui.Color
---@param source ui.Color
---@param factor number
---@param alpha_boost number
---@return ui.Color
function Color.brighten_to(out, source, factor, alpha_boost)
	out[1] = clamp01(source[1] * factor)
	out[2] = clamp01(source[2] * factor)
	out[3] = clamp01(source[3] * factor)
	out[4] = clamp01((source[4] or 1) + alpha_boost)
	return out
end

---@param out ui.Color
---@param a ui.Color
---@param b ui.Color
---@param t number
---@return ui.Color
function Color.mix_to(out, a, b, t)
	local aa = a[4] or 1
	local ba = b[4] or 1
	out[1] = a[1] + (b[1] - a[1]) * t
	out[2] = a[2] + (b[2] - a[2]) * t
	out[3] = a[3] + (b[3] - a[3]) * t
	out[4] = aa + (ba - aa) * t
	return out
end

---@param color ui.Color
function Color.apply(color)
	love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
end

return Color
