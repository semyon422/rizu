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

-- Keep this base palette synchronized with rizu_webclient/src/app/app.css.
local text = hex("F2F2FF")
local muted = hex("A6B2CC")
local panel = hex("211C2B")
local surface = hex("2D283E")
local surface_raised = hex("403854")
local background = hex("0D0C0F")
local outline = hex("4A4460")
local accent = hex("D9A04F")
local danger = hex("F64949")
local success = hex("7DB435")
local purple = hex("8838CE")
local magenta = hex("BE4CC0")
local blue = hex("435FA7")
local shadow = hex("000000")

---@class yi.Colors
local Colors = {
	text = text,
	muted = muted,
	panel = panel,
	surface = surface,
	surface_raised = surface_raised,
	background = background,
	outline = outline,
	accent = accent,
	danger = danger,
	success = success,
	purple = purple,
	magenta = magenta,
	blue = blue,
	shadow = shadow,
	overlay = hex("0D0C0F", 0.64),
	divider = hex("4A4460", 0.55),
	border_subtle = hex("F2F2FF", 0.07),

	grade_x = hex("00b4fc"),
	grade_s = hex("FFE342"),
	grade_a = hex("95FF74"),
	grade_b = hex("c57ffd"),
	grade_c = hex("f96baf"),
	grade_d = hex("ff6a78"),

	orange = hex("D4873E"),
	yellow = hex("C8BE3A"),
	cyan = hex("3EAECB"),
}

return Colors
