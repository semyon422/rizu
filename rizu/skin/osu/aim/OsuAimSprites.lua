local GROUP = "playfield"

local names = {
	"hitcircle",
	"hitcircleoverlay",
	"approachcircle",
	"sliderstartcircle",
	"sliderstartcircleoverlay",
	"reversearrow",
	"sliderendcircle",
	"sliderendcircleoverlay",
	"sliderfollowcircle",
	"sliderscorepoint",
	"cursor",
}

---@class rizu.skin.osu.aim.OsuAimSprites
---@field digits {[integer]: rizu.skin.SkinTextures.Image} Hit circle glyphs, indexed 0 to 9.
---@field digit_overlap number
---@field animation_framerate number?
---@field hitcircle rizu.skin.SkinTextures.Image?
---@field hitcircleoverlay rizu.skin.SkinTextures.Image?
---@field approachcircle rizu.skin.SkinTextures.Image?
---@field sliderstartcircle rizu.skin.SkinTextures.Image?
---@field sliderstartcircleoverlay rizu.skin.SkinTextures.Image?
---@field reversearrow rizu.skin.SkinTextures.Image?
---@field sliderendcircle rizu.skin.SkinTextures.Image?
---@field sliderendcircleoverlay rizu.skin.SkinTextures.Image?
---@field sliderb rizu.skin.SkinTextures.Image[]?
---@field sliderfollowcircle rizu.skin.SkinTextures.Image?
---@field sliderscorepoint rizu.skin.SkinTextures.Image?
---@field cursor rizu.skin.SkinTextures.Image?
---@field followpoint rizu.skin.SkinTextures.Image[]
---@field combo_colors number[][] RGB; used when the chart brings none.
---@field slider_border number[]? RGB
---@field slider_track number[]? RGB replacing the combo colour of slider bodies.
local OsuAimSprites = {}

local default_combo_colors = {{1, 192 / 255, 0}, {0, 202 / 255, 0}, {18 / 255, 124 / 255, 1}, {242 / 255, 24 / 255, 57 / 255}}

---@param value string?
---@return number[]?
local function parseColor(value)
	---@type string?, string?, string?
	local r, g, b = tostring(value):match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
	if r then return {tonumber(r) / 255, tonumber(g) / 255, tonumber(b) / 255} end
end

---@param graphics rizu.skin.SkinTextures
---@return string[]
local function sliderBallNames(graphics)
	---@type string[]
	local frames = {}
	-- osu! only treats numbered slider balls as an animation starting at frame 0,
	-- and stops at the first missing frame.
	while graphics:findAsset("sliderb" .. #frames, graphics.file_map) do
		frames[#frames + 1] = "sliderb" .. #frames
	end
	if #frames == 0 then frames[1] = "sliderb" end
	return frames
end

---@param graphics rizu.skin.SkinTextures
---@return {[string]: string}
local function getFonts(graphics)
	local ini = graphics.skin and graphics.skin.skin_ini
	return ini and ini.Fonts or {}
end

---@param graphics rizu.skin.SkinTextures
---@return string
local function getDigitPrefix(graphics)
	local prefix = getFonts(graphics).HitCirclePrefix
	return type(prefix) == "string" and prefix ~= "" and prefix or "default"
end

---Every aim sprite shares one atlas, so the playfield draws in few batches.
---@param graphics rizu.skin.SkinTextures
---@return rizu.skin.SkinTextures.Asset[]
function OsuAimSprites.getAssets(graphics)
	---@type rizu.skin.SkinTextures.Asset[]
	local assets = {}
	for _, name in ipairs(names) do assets[#assets + 1] = {name = name, group = GROUP} end
	for _, name in ipairs(sliderBallNames(graphics)) do assets[#assets + 1] = {name = name, group = GROUP} end
	assets[#assets + 1] = {name = "followpoint", animation = true, group = GROUP}
	local prefix = getDigitPrefix(graphics)
	for digit = 0, 9 do
		assets[#assets + 1] = {name = prefix .. "-" .. digit, fallback = "default-" .. digit, group = GROUP}
	end
	return assets
end

---Call after the graphics have loaded `getAssets`.
---@param graphics rizu.skin.SkinTextures
---@return rizu.skin.osu.aim.OsuAimSprites
function OsuAimSprites.load(graphics)
	---@type rizu.skin.osu.aim.OsuAimSprites
	local sprites = {
		digits = {}, digit_overlap = tonumber(getFonts(graphics).HitCircleOverlap) or -2,
		followpoint = graphics:getAnimationFrames("followpoint", nil, GROUP),
		combo_colors = {},
	}
	for _, name in ipairs(names) do sprites[name] = graphics:getFrames(name, nil, GROUP)[1] end

	---@type rizu.skin.SkinTextures.Image[]
	local slider_ball = {}
	for _, name in ipairs(sliderBallNames(graphics)) do
		slider_ball[#slider_ball + 1] = graphics:getFrames(name, nil, GROUP)[1]
	end
	if #slider_ball > 0 then sprites.sliderb = slider_ball end

	local prefix = getDigitPrefix(graphics)
	for digit = 0, 9 do
		sprites.digits[digit] = graphics:getFrames(prefix .. "-" .. digit, "default-" .. digit, GROUP)[1]
	end

	local ini = graphics.skin and graphics.skin.skin_ini
	if not sprites.sliderendcircle then
		sprites.sliderendcircleoverlay = nil
		-- Slider ends became invisible in skin version 2 unless the skin draws them itself.
		-- A skin.ini without a version is version 1; "latest" is not a number.
		local version = ini and ini.General and ini.General.Version
		if ini and (version == nil or (tonumber(version) or math.huge) < 2) then
			sprites.sliderendcircle, sprites.sliderendcircleoverlay = sprites.hitcircle, sprites.hitcircleoverlay
		end
	end
	local colours = ini and ini.Colours or {}
	for index = 1, 8 do
		sprites.combo_colors[#sprites.combo_colors + 1] = parseColor(colours["Combo" .. index])
	end
	if #sprites.combo_colors == 0 then sprites.combo_colors = default_combo_colors end
	sprites.slider_border = parseColor(colours.SliderBorder)
	sprites.slider_track = parseColor(colours.SliderTrackOverride)
	local framerate = tonumber(ini and ini.General and ini.General.AnimationFramerate)
	if framerate and framerate > 0 then sprites.animation_framerate = framerate end
	return sprites
end

return OsuAimSprites
