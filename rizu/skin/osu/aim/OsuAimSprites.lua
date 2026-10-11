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
---@field batch rizu.skin.osu.OsuSpriteBatch
---@field digits {[integer]: rizu.skin.osu.OsuSkinGraphics.Image} Hit circle glyphs, indexed 0 to 9.
---@field digit_overlap number
---@field animation_framerate number?
---@field hitcircle rizu.skin.osu.OsuSkinGraphics.Image?
---@field hitcircleoverlay rizu.skin.osu.OsuSkinGraphics.Image?
---@field approachcircle rizu.skin.osu.OsuSkinGraphics.Image?
---@field sliderstartcircle rizu.skin.osu.OsuSkinGraphics.Image?
---@field sliderstartcircleoverlay rizu.skin.osu.OsuSkinGraphics.Image?
---@field reversearrow rizu.skin.osu.OsuSkinGraphics.Image?
---@field sliderendcircle rizu.skin.osu.OsuSkinGraphics.Image?
---@field sliderendcircleoverlay rizu.skin.osu.OsuSkinGraphics.Image?
---@field sliderb rizu.skin.osu.OsuSkinGraphics.Image[]?
---@field sliderfollowcircle rizu.skin.osu.OsuSkinGraphics.Image?
---@field sliderscorepoint rizu.skin.osu.OsuSkinGraphics.Image?
---@field cursor rizu.skin.osu.OsuSkinGraphics.Image?
local OsuAimSprites = {}

---@param graphics rizu.skin.osu.OsuSkinGraphics
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

---@param graphics rizu.skin.osu.OsuSkinGraphics
---@return {[string]: string}
local function getFonts(graphics)
	local ini = graphics.skin and graphics.skin.skin_ini
	return ini and ini.Fonts or {}
end

---@param graphics rizu.skin.osu.OsuSkinGraphics
---@return string
local function getDigitPrefix(graphics)
	local prefix = getFonts(graphics).HitCirclePrefix
	return type(prefix) == "string" and prefix ~= "" and prefix or "default"
end

---Every aim sprite shares one atlas, so the playfield draws in few batches.
---@param graphics rizu.skin.osu.OsuSkinGraphics
---@return rizu.skin.osu.OsuSkinGraphics.Asset[]
function OsuAimSprites.getAssets(graphics)
	---@type rizu.skin.osu.OsuSkinGraphics.Asset[]
	local assets = {}
	for _, name in ipairs(names) do assets[#assets + 1] = {name = name, group = GROUP} end
	for _, name in ipairs(sliderBallNames(graphics)) do assets[#assets + 1] = {name = name, group = GROUP} end
	local prefix = getDigitPrefix(graphics)
	for digit = 0, 9 do
		assets[#assets + 1] = {name = prefix .. "-" .. digit, fallback = "default-" .. digit, group = GROUP}
	end
	return assets
end

---Call after the graphics have loaded `getAssets`.
---@param graphics rizu.skin.osu.OsuSkinGraphics
---@return rizu.skin.osu.aim.OsuAimSprites
function OsuAimSprites.load(graphics)
	---@type rizu.skin.osu.aim.OsuAimSprites
	local sprites = {batch = graphics.batch, digits = {}, digit_overlap = tonumber(getFonts(graphics).HitCircleOverlap) or -2}
	for _, name in ipairs(names) do sprites[name] = graphics:getFrames(name, nil, GROUP)[1] end

	---@type rizu.skin.osu.OsuSkinGraphics.Image[]
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
	local framerate = tonumber(ini and ini.General and ini.General.AnimationFramerate)
	if framerate and framerate > 0 then sprites.animation_framerate = framerate end
	return sprites
end

return OsuAimSprites
