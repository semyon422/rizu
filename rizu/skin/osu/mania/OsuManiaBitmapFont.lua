local class = require("class")

local lg = love.graphics

local CHARACTER_SUFFIXES = {
	[46] = "dot", [44] = "comma", [37] = "percent", [47] = "slash",
	[92] = "fps", [61] = "ms", [43] = "hz", [120] = "x",
}
local DIGIT_SUFFIXES = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}

---@class rizu.skin.osu.mania.OsuManiaBitmapFont.Glyph
---@field image love.Image
---@field width number
---@field height number
---@field advance number
---@field digit boolean

---@class rizu.skin.osu.mania.OsuManiaBitmapFont
---@operator call: rizu.skin.osu.mania.OsuManiaBitmapFont
---@field graphics rizu.skin.osu.mania.OsuManiaSkinGraphics
---@field prefix string
---@field overlap number
---@field image_cache {[string]: love.Image|false}
---@field image_cache_generation integer
---@field glyphs rizu.skin.osu.mania.OsuManiaBitmapFont.Glyph[]
---@field glyph_count integer
---@field measured_value string?
---@field measured_width number
---@field measured_height number
local OsuManiaBitmapFont = class()

---@param graphics rizu.skin.osu.mania.OsuManiaSkinGraphics
---@param prefix string?
---@param overlap number?
function OsuManiaBitmapFont:new(graphics, prefix, overlap)
	self.graphics = graphics
	self.prefix = prefix or "score"
	self.overlap = overlap or 0
	self.image_cache = {}
	self.image_cache_generation = -1
	self.glyphs = {}
	self.glyph_count = 0
	self.measured_value = nil
	self.measured_width = 0
	self.measured_height = 0
end

---@param skin rizu.skin.OsuSkinDiscovery?
---@param font_name "Score"|"Combo"
function OsuManiaBitmapFont:setSkin(skin, font_name)
	local fonts = skin and skin.skin_ini.Fonts or {}
	local prefix, overlap
	for name, value in pairs(fonts) do
		if type(name) == "string" then
			if name:lower() == (font_name .. "Prefix"):lower() then prefix = value end
			if name:lower() == (font_name .. "Overlap"):lower() then overlap = value end
		end
	end
	if type(prefix) ~= "string" or prefix == "" then prefix = "score" end
	overlap = tonumber(overlap) or 0
	if overlap ~= overlap or overlap == math.huge or overlap == -math.huge then overlap = 0 end
	self.prefix = prefix
	self.overlap = overlap
	self.image_cache = {}
	self.image_cache_generation = -1
	self.measured_value = nil
end

---@param character_code integer
---@return string?
local function character_suffix(character_code)
	if character_code >= 48 and character_code <= 57 then return DIGIT_SUFFIXES[character_code - 47] end
	return CHARACTER_SUFFIXES[character_code]
end

---@param suffix string
---@return love.Image?
function OsuManiaBitmapFont:getImage(suffix)
	if self.image_cache_generation ~= self.graphics.generation then
		self.image_cache = {}
		self.image_cache_generation = self.graphics.generation
		self.measured_value = nil
		for index = 1, #self.glyphs do
			local glyph = self.glyphs[index]
			glyph.image, glyph.width, glyph.height, glyph.advance, glyph.digit = nil, nil, nil, nil, nil
		end
	end
	local cached = self.image_cache[suffix]
	if cached ~= nil then return cached ~= false and cached or nil end
	local image = self.graphics:getFrames(self.prefix .. "-" .. suffix, "score-" .. suffix)[1]
	self.image_cache[suffix] = image or false
	return image
end

---@param image love.Image?
---@return number width
---@return number height
function OsuManiaBitmapFont:getImageDimensions(image)
	if not image then return 0, 0 end
	if image.getDimensions then return image:getDimensions() end
	return image:getWidth(), image:getHeight()
end

---@param include_combo_suffix boolean?
---@return string[]
function OsuManiaBitmapFont:getImageAssets(include_combo_suffix)
	local names = {}
	for digit = 0, 9 do names[#names + 1] = self.prefix .. "-" .. digit end
	for _, suffix in ipairs({"dot", "comma", "percent", "slash", "fps", "ms", "hz"}) do
		names[#names + 1] = self.prefix .. "-" .. suffix
	end
	if include_combo_suffix then names[#names + 1] = self.prefix .. "-x" end
	return names
end

---@param value string
---@return number width
---@return number height
function OsuManiaBitmapFont:measure(value)
	local generation = self.graphics.generation
	if self.measured_value == value and self.image_cache_generation == generation then return self.measured_width, self.measured_height end
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
	self.measured_width = math.max(0, width - count * self.overlap)
	self.measured_height = height
	return self.measured_width, self.measured_height
end

---@param value string
---@param scale number
---@param y number
---@param right_edge number
---@param color number[]?
function OsuManiaBitmapFont:draw(value, scale, y, right_edge, color)
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
	local draw_x = right_edge - math.max(0, total_width - glyph_count * self.overlap) * scale
	for index = 1, glyph_count do
		local glyph = glyphs[index]
		local offset_x = glyph.digit and math.max(0, (slot_width - glyph.width) / 2) or 0
		local offset_y = (max_height - glyph.height) / 2
		if color then
			lg.setColor(color[1], color[2], color[3], color[4] or 1)
		else
			lg.setColor(1, 1, 1, 1)
		end
		lg.draw(glyph.image, draw_x + offset_x * scale, y + offset_y * scale, 0, scale, scale)
		draw_x = draw_x + (glyph.advance - self.overlap) * scale
	end
	return max_height * scale
end

return OsuManiaBitmapFont
