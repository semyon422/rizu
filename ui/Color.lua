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

---@param out gui.Color
---@param r number
---@param g number
---@param b number
---@param a number
---@return gui.Color
function Color.set(out, r, g, b, a)
	out[1], out[2], out[3], out[4] = r, g, b, a
	return out
end

---@param out gui.Color
---@param source gui.Color
---@return gui.Color
function Color.copy_to(out, source)
	out[1] = source[1]
	out[2] = source[2]
	out[3] = source[3]
	out[4] = source[4] or 1
	return out
end

---@param out gui.Color
---@param source gui.Color
---@param rgb_scale number
---@param alpha_scale number
---@return gui.Color
function Color.scale_to(out, source, rgb_scale, alpha_scale)
	out[1] = clamp01(source[1] * rgb_scale)
	out[2] = clamp01(source[2] * rgb_scale)
	out[3] = clamp01(source[3] * rgb_scale)
	out[4] = (source[4] or 1) * alpha_scale
	return out
end

---@param out gui.Color
---@param source gui.Color
---@param alpha_scale number
---@return gui.Color
function Color.scale_alpha_to(out, source, alpha_scale)
	out[1] = source[1]
	out[2] = source[2]
	out[3] = source[3]
	out[4] = (source[4] or 1) * alpha_scale
	return out
end

---@param out gui.Color
---@param source gui.Color
---@param factor number
---@param alpha_boost number
---@return gui.Color
function Color.brighten_to(out, source, factor, alpha_boost)
	out[1] = clamp01(source[1] * factor)
	out[2] = clamp01(source[2] * factor)
	out[3] = clamp01(source[3] * factor)
	out[4] = clamp01((source[4] or 1) + alpha_boost)
	return out
end

---@param out gui.Color
---@param a gui.Color
---@param b gui.Color
---@param t number
---@return gui.Color
function Color.mix_to(out, a, b, t)
	local aa = a[4] or 1
	local ba = b[4] or 1
	out[1] = a[1] + (b[1] - a[1]) * t
	out[2] = a[2] + (b[2] - a[2]) * t
	out[3] = a[3] + (b[3] - a[3]) * t
	out[4] = aa + (ba - aa) * t
	return out
end

---@param h number
---@param s number
---@param v number
---@param out gui.Color
---@return gui.Color
function Color.HSV(h, s, v, out)
	if s <= 0 then return {v, v, v, 1} end
	h = h * 6
	local c = v * s
	local x = (1 - math.abs((h % 2) - 1)) * c
	local m, r, g, b = (v - c), 0, 0, 0
	if h < 1 then
		r, g, b = c, x, 0
	elseif h < 2 then
		r, g, b = x, c, 0
	elseif h < 3 then
		r, g, b = 0, c, x
	elseif h < 4 then
		r, g, b = 0, x, c
	elseif h < 5 then
		r, g, b = x, 0, c
	else
		r, g, b = c, 0, x
	end
	out[1] = r + m
	out[2] = g + m
	out[3] = b + m
	return out
end

---@param x number
---@return number
function Color.convertDiffToHue(x)
	if x <= 0.5 then
		return 0.5 - x
	elseif x <= 0.75 then
		return 1 - (x - 0.5) * (1 - 0.8) / 0.25
	else
		return 0.8
	end
end

---@param diff number
---@param out gui.Color
---@return gui.Color
function Color.enpsToColor(diff, out)
	local hue = Color.convertDiffToHue((math.min(diff, 30) / 30))
	return Color.HSV(hue, 1, 1, out)
end

---@param diff number
---@param out gui.Color
---@return gui.Color
function Color.msdToColor(diff, out)
	local hue = Color.convertDiffToHue((math.min(diff, 40) / 40) / 1.3)
	return Color.HSV(hue, 1, 1, out)
end

---@param diff number
---@param out gui.Color
---@return gui.Color
function Color.osuToColor(diff, out)
	local hue = Color.convertDiffToHue((math.min(diff, 10) / 10))
	return Color.HSV(hue, 1, 1, out)
end

---@param rate number
---@param out gui.Color
---@return gui.Color
function Color.linearRateToColor(rate, out)
	local hue = Color.convertDiffToHue(rate / 4)
	return Color.HSV(hue, rate / 4, 1, out)
end

---@param ln_percent number
---@param out gui.Color
---@return gui.Color
function Color.lnPercentToColor(ln_percent, out)
	local hue = Color.convertDiffToHue(ln_percent)
	return Color.HSV(hue, ln_percent, 1, out)
end

return Color
