local ui_colors = {
	cyan_400 = {34, 211, 238, 255},
	cyan_200 = {165, 243, 252, 255},
	cyan_100 = {207, 250, 254, 255},
	cyan_500_30 = {6, 182, 212, 77},
	cyan_400_50 = {34, 211, 238, 128},
	cyan_400_25 = {34, 211, 238, 64},
	cyan_400_10 = {34, 211, 238, 26},

	red_500 = {239, 68, 68, 255},
	emerald_400 = {52, 211, 153, 255},
	amber_400 = {251, 191, 36, 255},

	black = {0, 0, 0, 255},
	black_80 = {0, 0, 0, 204},
	black_70 = {0, 0, 0, 255 * 0.7},
	black_60 = {0, 0, 0, 255 * 0.6},
	black_50 = {0, 0, 0, 128},
	black_40 = {0, 0, 0, 255 * 0.4},

	slate_900 = {15, 23, 42, 255},
	slate_900_70 = {15, 23, 42, 179},

	slate_800 = {30, 41, 59, 255},
	slate_800_80 = {30, 41, 59, 204},
	slate_700_80 = {51, 65, 85, 204},
	slate_600 = {71, 85, 105, 255},
	slate_400 = {148, 163, 184, 255},

	blue_900_40 = {30, 58, 138, 102},
	transparent = {0, 0, 0, 0},

	white = {255, 255, 255, 255},
	white_90 = {255, 255, 255, 230},
	white_80 = {255, 255, 255, 255 * 0.8},
	white_70 = {255, 255, 255, 179},
	white_50 = {255, 255, 255, 128},
	white_40 = {255, 255, 255, 102},
	white_30 = {255, 255, 255, 77},
	white_10 = {255, 255, 255, 26},
	white_5 = {255, 255, 255, 13},

	text_title = {235, 245, 255, 255},
	text_section = {220, 235, 255, 255},
	text_subsection = {160, 180, 205, 255},
	text_label = {200, 215, 235, 255},
	text_muted = {130, 150, 175, 255},
}

local Colors = {}

for k, v in pairs(ui_colors) do
	Colors[k] = {love.math.colorFromBytes(v[1], v[2], v[3], v[4])}
end

---@param h number
---@param s number
---@param v number
---@return number[]
function Colors.HSV(h, s, v)
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
	return {r + m, g + m, b + m, 1}
end

---@param x number
---@return number
function Colors.convertDiffToHue(x)
	if x <= 0.5 then
		return 0.5 - x
	elseif x <= 0.75 then
		return 1 - (x - 0.5) * (1 - 0.8) / 0.25
	else
		return 0.8
	end
end

return Colors
