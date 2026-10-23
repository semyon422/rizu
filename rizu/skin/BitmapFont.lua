local class = require("class")
local TextureImage = require("rizu.skin.TextureImage")

local lg = love.graphics

local CHARACTER_SUFFIXES = {
	[46] = "dot", [44] = "comma", [37] = "percent", [47] = "slash",
	[92] = "fps", [61] = "ms", [43] = "hz", [120] = "x",
}
local DIGIT_SUFFIXES = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}

---@class rizu.skin.BitmapFont.Glyph
---@field image rizu.skin.SkinTextures.Image?
---@field width number?
---@field height number?
---@field advance number?
---@field digit boolean?

---Text drawn with one sprite per character: `<prefix>-0` .. `<prefix>-9`, `<prefix>-dot`,
---`-comma`, `-percent`, `-slash`, `-x`... A glyph the prefix lacks falls back to the `score-`
---glyph of the skin, then of the fallback archive.
---@class rizu.skin.BitmapFont
---@operator call: rizu.skin.BitmapFont
---@field graphics rizu.skin.SkinTextures
---@field group string? Atlas group the glyphs were requested in.
---@field prefix string
---@field overlap number Pixels neighbouring glyphs overlap by; negative spreads them.
---@field image_cache {[string]: rizu.skin.SkinTextures.Image|false}
---@field glyphs rizu.skin.BitmapFont.Glyph[]
---@field glyph_count integer
---@field measured_value string?
---@field measured_width number
---@field measured_height number
local BitmapFont = class()

BitmapFont.fallback_prefix = "score"

---@param graphics rizu.skin.SkinTextures
---@param prefix string?
---@param overlap number?
---@param group string?
function BitmapFont:new(graphics, prefix, overlap, group)
	self.graphics = graphics
	self.prefix = prefix or BitmapFont.fallback_prefix
	self.group = group
	self.overlap = overlap or 0
	self.image_cache = {}
	self.glyphs = {}
	self.glyph_count = 0
	self.measured_value = nil
	self.measured_width = 0
	self.measured_height = 0
end

---Every glyph with its fallback, to request before loading the textures.
---@param prefix string
---@param group string?
---@return rizu.skin.SkinTextures.Asset[]
function BitmapFont.getAssets(prefix, group)
	local suffixes = {} ---@type string[]
	for _, suffix in ipairs(DIGIT_SUFFIXES) do suffixes[#suffixes + 1] = suffix end
	for _, suffix in pairs(CHARACTER_SUFFIXES) do suffixes[#suffixes + 1] = suffix end
	table.sort(suffixes)
	local assets = {} ---@type rizu.skin.SkinTextures.Asset[]
	for _, suffix in ipairs(suffixes) do
		assets[#assets + 1] = {name = prefix .. "-" .. suffix, fallback = BitmapFont.fallback_prefix .. "-" .. suffix,
			group = group}
	end
	return assets
end

function BitmapFont:load()
	self:unload()
end

---Drop font-local resource references at lifecycle boundaries, not in draw().
function BitmapFont:unload()
	self.image_cache = {}
	self.measured_value = nil
	for _, glyph in ipairs(self.glyphs) do
		glyph.image, glyph.width, glyph.height, glyph.advance, glyph.digit = nil, nil, nil, nil, nil
	end
end

---@param character_code integer
---@return string?
local function character_suffix(character_code)
	if character_code >= 48 and character_code <= 57 then return DIGIT_SUFFIXES[character_code - 47] end
	return CHARACTER_SUFFIXES[character_code]
end

---@param suffix string
---@return rizu.skin.SkinTextures.Image?
function BitmapFont:getImage(suffix)
	local cached = self.image_cache[suffix]
	if cached ~= nil then return cached ~= false and cached or nil end
	local image = self.graphics:getFrames(self.prefix .. "-" .. suffix, BitmapFont.fallback_prefix .. "-" .. suffix, self.group)[1]
	self.image_cache[suffix] = image or false
	return image
end

---@param image rizu.skin.SkinTextures.Image?
---@return number width
---@return number height
function BitmapFont:getImageDimensions(image)
	if not image then return 0, 0 end
	return TextureImage.dimensions(image)
end

---@param value string
---@return number width
---@return number height
function BitmapFont:measure(value)
	if self.measured_value == value then return self.measured_width, self.measured_height end
	local slot_width, digit_height = self:getImageDimensions(self:getImage("5"))
	if slot_width <= 0 then slot_width = 16 end
	local width, height, count = 0, digit_height, 0
	for index = 1, #value do
		local character_code = value:byte(index)
		local image = self:getImage(character_suffix(character_code) or "")
		local image_width, image_height = self:getImageDimensions(image)
		local digit = character_code >= 48 and character_code <= 57
		local advance = digit and slot_width or image_width
		if advance > 0 then
			width = width + advance
			height = math.max(height, image_height)
			count = count + 1
		end
	end
	self.measured_value = value
	self.measured_width = math.max(0, width - math.max(0, count - 1) * self.overlap)
	self.measured_height = height
	return self.measured_width, self.measured_height
end

---@param value string
---@param scale number
---@param y number
---@param right_edge number
---@param color number[]?
function BitmapFont:draw(value, scale, y, right_edge, color)
	local glyphs = self.glyphs
	local glyph_count = 0
	local slot_width = self:getImageDimensions(self:getImage("5"))
	if slot_width <= 0 then slot_width = 16 end
	local max_height, total_width = 0, 0
	for index = 1, #value do
		local character_code = value:byte(index)
		local suffix = character_suffix(character_code)
		local image = suffix and self:getImage(suffix)
		local width, height = self:getImageDimensions(image)
		local digit = character_code >= 48 and character_code <= 57
		local advance = digit and slot_width or width
		if image and advance > 0 then
			max_height = math.max(max_height, height)
			glyph_count = glyph_count + 1
			local glyph = glyphs[glyph_count]
			if not glyph then
				glyph = {}
				glyphs[glyph_count] = glyph
			end
			glyph.image, glyph.width, glyph.height = image, width, height
			glyph.advance, glyph.digit = advance, digit
			total_width = total_width + advance
		end
	end
	self.glyph_count = glyph_count
	for index = glyph_count + 1, #glyphs do
		local glyph = glyphs[index]
		glyph.image, glyph.width, glyph.height, glyph.advance, glyph.digit = nil, nil, nil, nil, nil
	end
	local draw_x = right_edge - math.max(0, total_width - math.max(0, glyph_count - 1) * self.overlap) * scale
	for index = 1, glyph_count do
		local glyph = glyphs[index]
		local offset_x = glyph.digit and math.max(0, (slot_width - glyph.width) / 2) or 0
		local offset_y = (max_height - glyph.height) / 2
		if color then
			lg.setColor(color[1], color[2], color[3], color[4] or 1)
		else
			lg.setColor(1, 1, 1, 1)
		end
		TextureImage.draw(glyph.image, draw_x + offset_x * scale, y + offset_y * scale, 0, scale, scale)
		draw_x = draw_x + (glyph.advance - self.overlap) * scale
	end
	return max_height * scale
end

return BitmapFont
