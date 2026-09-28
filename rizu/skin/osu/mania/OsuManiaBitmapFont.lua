local class = require("class")

local lg = love.graphics

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
local OsuManiaBitmapFont = class()

---@param graphics rizu.skin.osu.mania.OsuManiaSkinGraphics
---@param prefix string?
---@param overlap number?
function OsuManiaBitmapFont:new(graphics, prefix, overlap)
	self.graphics = graphics
	self.prefix = prefix or "score"
	self.overlap = overlap or 0
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
end

---@param character string
---@return string?
local function character_suffix(character)
	if character:match("%d") then return character end
	local suffixes = {
		["."] = "dot", [","] = "comma", ["%"] = "percent", ["/"] = "slash",
		["\\"] = "fps", ["="] = "ms", ["+"] = "hz", ["x"] = "x",
	}
	return suffixes[character]
end

---@param suffix string
---@return love.Image?
function OsuManiaBitmapFont:getImage(suffix)
	return self.graphics:getFrames(self.prefix .. "-" .. suffix, nil)[1]
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
	local slot_width, digit_height = self:getImageDimensions(self:getImage("5"))
	if slot_width <= 0 then slot_width = 16 end
	local width, height, count = 0, digit_height, 0
	for character in value:gmatch(".") do
		local image = self:getImage(character_suffix(character) or "")
		local image_width, image_height = self:getImageDimensions(image)
		local advance = character:match("%d") and slot_width or image_width
		if advance > 0 then
			width = width + advance
			height = math.max(height, image_height)
			count = count + 1
		end
	end
	return math.max(0, width - count * self.overlap), height
end

---@param value string
---@param scale number
---@param y number
---@param right_edge number
---@param color number[]?
function OsuManiaBitmapFont:draw(value, scale, y, right_edge, color)
	---@type rizu.skin.osu.mania.OsuManiaBitmapFont.Glyph[]
	local glyphs = {}
	local slot_width = self:getImageDimensions(self:getImage("5"))
	if slot_width <= 0 then slot_width = 16 end
	local max_height, total_width = 0, 0
	for character in value:gmatch(".") do
		local suffix = character_suffix(character)
		local image = suffix and self:getImage(suffix)
		local width, height = self:getImageDimensions(image)
		local digit = character:match("%d") ~= nil
		local advance = digit and slot_width or width
		if image and advance > 0 then
			max_height = math.max(max_height, height)
			glyphs[#glyphs + 1] = {image = image, width = width, height = height, advance = advance, digit = digit}
			total_width = total_width + advance
		end
	end
	local draw_x = right_edge - math.max(0, total_width - #glyphs * self.overlap) * scale
	for _, glyph in ipairs(glyphs) do
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
