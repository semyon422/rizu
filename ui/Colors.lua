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

---@class yi.Colors
local Colors = {
	text = hex("F2F2FF"),
	text_muted = hex("A6B2CC"),
	panel = hex("211C2B"),
	panel_alt = hex("2A2336"),
	hover = hex("403854"),
	outline = hex("4A4460"),
	background = hex("0D0C0F"),
	elements = hex("2D283E"),
	accent = hex("D9A04F"),
	accent2 = hex("E2B13C"),

	grade_x = hex("00b4fc"),
	grade_s = hex("FFE342"),
	grade_a = hex("95FF74"),
	grade_b = hex("c57ffd"),
	grade_c = hex("f96baf"),
	grade_d = hex("ff6a78"),

	green = hex("639B3D"),
	blue = hex("435FA7"),

	back_button = hex("F64949"),
	play_button = hex("7DB435"),
}

return Colors
