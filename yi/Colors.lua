---@param str string
---@param alpha number?
---@return [number, number, number, number]
local function hex(str, alpha)
	str = str:gsub("#", "")

	if #str ~= 6 then
		error("Invalid hex")
	end

	local r = tonumber(str:sub(1, 2), 16)
	local g = tonumber(str:sub(3, 4), 16)
	local b = tonumber(str:sub(5, 6), 16)

	if not (r and g and b) then
		error("Invalid hex characters found in string.")
	end

	alpha = math.max(0, math.min(1, alpha or 1))

	return {
		r / 255,
		g / 255,
		b / 255,
		alpha
	}
end

local background = hex("0C0C11")

---@class yi.Colors
local Colors = {
	accent = hex("00CCFF"),
	text = hex("F2F2FF"),
	text_muted = hex("A6B2CC"),
	text_shadow = hex("0A0E17", 0.6),
	line = hex("464B5C"),
	background = background,

	select_bg_gradient = {love.math.colorFromBytes(15, 23, 42, 179)},
	select_side_panel_bg = background,
	icon_button_bg = hex("1E2835"),
	icon_button_bg_hover = hex("51627A"),
	icon_content = hex("F2F2FF")
}

return Colors
