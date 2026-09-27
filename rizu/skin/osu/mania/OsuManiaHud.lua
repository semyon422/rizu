local class = require("class")

local lg = love.graphics
local FIELD_WIDTH, FIELD_HEIGHT = 640, 480
local SCORE_Y, SCORE_SCALE = 2, 0.6
local ACCURACY_Y, ACCURACY_SCALE = 58, 0.38
local COMBO_SCALE = 0.36
local PROGRESS_RADIUS = 9

---@class rizu.skin.osu.mania.OsuManiaHud
---@operator call: rizu.skin.osu.mania.OsuManiaHud
---@field game sphere.GameController
---@field skin rizu.skin.OsuSkinDiscovery?
---@field skin_graphics rizu.skin.osu.mania.OsuManiaSkinGraphics
---@field combo_position number
---@field combo_prefix string
---@field score_prefix string
---@field combo_overlap number
---@field score_overlap number
---@field upside_down boolean
local OsuManiaHud = class()

---@param game sphere.GameController
---@param skin_graphics rizu.skin.osu.mania.OsuManiaSkinGraphics
function OsuManiaHud:new(game, skin_graphics)
	self.game = game
	self.skin_graphics = skin_graphics
	self:loadSkin(nil, {}, false)
end

---@param section rizu.skin.OsuSkinIni.ManiaSection
---@param key string
---@param default number
---@return number
local function get_number(section, key, default)
	local lowered_key = key:lower()
	local value = section[key]
	if value == nil then
		for name, candidate in pairs(section) do
			if name:lower() == lowered_key then value = candidate break end
		end
	end
	local number = tonumber(value)
	if number == nil or number ~= number or number == math.huge or number == -math.huge then
		return default
	end
	return number
end

---@param section rizu.skin.OsuSkinIni.ManiaSection
---@param key string
---@param default string
---@return string
local function get_string(section, key, default)
	local lowered_key = key:lower()
	local value = section[key]
	if value == nil then
		for name, candidate in pairs(section) do
			if name:lower() == lowered_key then value = candidate break end
		end
	end
	return value or default
end

---@param skin rizu.skin.OsuSkinDiscovery?
---@param section rizu.skin.OsuSkinIni.ManiaSection
---@param upside_down boolean
function OsuManiaHud:loadSkin(skin, section, upside_down)
	self.skin = skin
	self.combo_position = get_number(section, "ComboPosition", 111)
	local fonts = skin and skin.skin_ini.Fonts or {}
	self.combo_prefix = get_string(fonts, "ComboPrefix", "score")
	self.score_prefix = get_string(fonts, "ScorePrefix", "score")
	self.combo_overlap = get_number(fonts, "ComboOverlap", 0)
	self.score_overlap = get_number(fonts, "ScoreOverlap", 0)
	self.upside_down = upside_down
end

---@param prefix string
---@param value string
---@param x number
---@param y number
---@param scale number
---@param align "left"|"center"|"right"
---@param vertical_align "top"|"center"
---@param overlap number
---@param max_digit_width number
---@return number width
---@return number height
local function draw_value(graphics, prefix, value, x, y, scale, align, vertical_align, overlap, max_digit_width)
	local images = {}
	local width, height = 0, 0
	for character in value:gmatch(".") do
		local suffix = character
		if character == "." then suffix = "dot"
		elseif character == "," then suffix = "comma"
		elseif character == "%" then suffix = "percent"
		elseif character == "x" or character == "X" then suffix = "x" end
		local image = graphics:getFrames(prefix .. "-" .. suffix, nil)[1]
		images[#images + 1] = {image = image, character = character}
		if image then
			local image_width, image_height = image:getDimensions()
			width = width + (character:match("%d") and math.max(image_width, max_digit_width) or image_width) - overlap
			height = math.max(height, image_height)
		end
	end
	if width > 0 then width = width + overlap end
	if align == "center" then x = x - width * scale / 2
	elseif align == "right" then x = x - width * scale end

	local draw_x = x
	for _, item in ipairs(images) do
		local image = item.image
		if image then
			local image_width, image_height = image:getDimensions()
			local character_width = item.character:match("%d") and math.max(image_width, max_digit_width) or image_width
			local offset_x = (character_width - image_width) / 2
			local offset_y = vertical_align == "center" and (height - image_height) / 2 or 0
			lg.setColor(1, 1, 1, 1)
			lg.draw(image, draw_x + offset_x * scale, y + offset_y * scale, 0, scale, scale)
			draw_x = draw_x + (character_width - overlap) * scale
		end
	end
	return width * scale, height * scale
end

---@param progress number
---@return number start_angle
---@return number end_angle
function OsuManiaHud.getProgressArc(progress)
	progress = math.max(-1, math.min(1, progress))
	local start, finish
	if progress < 0 then
		start, finish = 1 + progress, 1
	else
		start, finish = 0, progress
	end
	return (start - 0.25) * math.pi * 2, (finish - 0.25) * math.pi * 2
end

---@param field_left number
---@param field_width number
---@return number right_x
---@return number combo_center_x
---@return number top_y
---@return number scale
function OsuManiaHud:getLayout(renderer, width, height, field_left, field_width)
	local scale, offset_x, offset_y = renderer:getFieldTransform(width, height)
	if scale <= 0 then return 0, 0, 0, 0 end
	return width / scale,
		field_left + field_width / 2 + offset_x / scale,
		offset_y / scale,
		scale
end

---@return string[]
function OsuManiaHud:getImageAssets()
	local names, seen = {}, {}
	local prefixes = {self.score_prefix, self.combo_prefix}
	for _, prefix in ipairs(prefixes) do
		local function add(suffix)
			local name = prefix .. "-" .. suffix
			if not seen[name] then
				seen[name] = true
				names[#names + 1] = name
			end
		end
		for digit = 0, 9 do add(tostring(digit)) end
		for _, suffix in ipairs({"dot", "comma", "percent", "x"}) do add(suffix) end
	end
	return names
end

---@param renderer rizu.skin.osu.OsuManiaRenderer
---@param width number
---@param height number
---@param transform love.Transform
---@param field_left number
---@param field_width number
function OsuManiaHud:draw(renderer, width, height, transform, field_left, field_width)
	local engine = self.game.rhythm_engine
	if not engine then return end
	local score_engine = engine.score_engine

	local max_digit_width = 0
	if score_engine then
		for digit = 0, 9 do
			local image = self.skin_graphics:getFrames(self.score_prefix .. "-" .. digit, nil)[1]
			if image then max_digit_width = math.max(max_digit_width, image:getWidth()) end
		end
	end

	local score_source = score_engine and score_engine.scoreSource
	local score_text, accuracy_text
	if score_engine and score_source and score_source.getScore then
		local value = score_source:getScore() * (score_source.score_multiplier or 1)
		local format = score_source.score_format or "%d"
		score_text = type(format) == "string" and format:format(value) or tostring(value)
		local accuracy_source = score_engine.accuracySource
		if accuracy_source and accuracy_source.getAccuracy then
			local accuracy = accuracy_source:getAccuracy() * (accuracy_source.accuracy_multiplier or 1)
			local format_accuracy = accuracy_source.accuracy_format or "%0.02f"
			accuracy_text = format_accuracy:format(accuracy)
		end
	end

	local combo_source = score_engine and score_engine.comboSource
	local combo = combo_source and combo_source.getCombo and tostring(combo_source:getCombo()) or nil

	local right_x, combo_center_x, top_y, scale = self:getLayout(renderer, width, height, field_left, field_width)
	if scale <= 0 then return end
	lg.push("all")
	lg.applyTransform(transform)
	lg.scale(scale)

	if score_text then
		draw_value(self.skin_graphics, self.score_prefix, score_text, right_x - 4, top_y + SCORE_Y, SCORE_SCALE,
			"right", "top", self.score_overlap, max_digit_width)
	end
	local accuracy_width, accuracy_height = 0, 0
	if accuracy_text then
		accuracy_width, accuracy_height = draw_value(self.skin_graphics, self.score_prefix, accuracy_text,
			right_x - 4, top_y + ACCURACY_Y, ACCURACY_SCALE, "right", "top", self.score_overlap, max_digit_width)
	end
	if combo then
		local combo_y = top_y + (self.upside_down and FIELD_HEIGHT - self.combo_position or self.combo_position)
		draw_value(self.skin_graphics, self.combo_prefix, combo, combo_center_x, combo_y, COMBO_SCALE,
			"center", "center", self.combo_overlap, max_digit_width)
	end

	local progress = engine.getProgress and engine:getProgress() or 0
	if type(progress) ~= "number" or progress ~= progress or progress == math.huge or progress == -math.huge then
		progress = 0
	end
	local radius = PROGRESS_RADIUS
	local x = right_x - 4 - accuracy_width - radius - 3
	local y = top_y + ACCURACY_Y + math.max(accuracy_height / 2, radius)
	local start_angle, end_angle = OsuManiaHud.getProgressArc(progress)
	lg.setColor(1, 1, 1, 0.35)
	lg.circle("fill", x, y, radius)
	if end_angle > start_angle then
		lg.setColor(1, 1, 1, 0.9)
		lg.arc("fill", "pie", x, y, radius, start_angle, end_angle, 36)
	end
	lg.setColor(1, 1, 1, 0.8)
	lg.circle("line", x, y, radius)
	lg.pop()
end

return OsuManiaHud
