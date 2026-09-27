local View = require("rizu.skin.View")

local lg = love.graphics
local SCORE_DIGITS = 8
local SCORE_SCALE = 0.96 * 0.625
local ACCURACY_SCALE = SCORE_SCALE * 0.6
local NEW_LAYOUT_GAP = 3
local SCORE_ANIMATION_RATE = 0.75
local ACCURACY_ANIMATION_RATE = 0.5

---@class rizu.skin.osu.mania.OsuManiaScoreView.Glyph
---@field image love.Image?
---@field width number
---@field height number
---@field advance number
---@field digit boolean

---@class rizu.skin.osu.mania.OsuManiaScoreView : rizu.skin.View
---@operator call: rizu.skin.osu.mania.OsuManiaScoreView
---@overload fun(graphics: rizu.skin.osu.mania.OsuManiaSkinGraphics): rizu.skin.osu.mania.OsuManiaScoreView
---@field graphics rizu.skin.osu.mania.OsuManiaSkinGraphics
---@field score_prefix string
---@field score_overlap number
---@field score number
---@field accuracy number
---@field target_score number
---@field target_accuracy number
---@field has_score boolean
---@field has_accuracy boolean
local OsuManiaScoreView = View + {}

---@param graphics rizu.skin.osu.mania.OsuManiaSkinGraphics
function OsuManiaScoreView:new(graphics)
	assert(type(graphics) == "table", "osu mania score view requires skin graphics")
	self.graphics = graphics
	self.score_prefix = "score"
	self.score_overlap = 0
	self.score = 0
	self.accuracy = 0
	self.target_score = 0
	self.target_accuracy = 0
	self.has_score = false
	self.has_accuracy = false
	View.new(self, {
		anchor = "top_right",
		origin = "top_right",
		width = 0,
		height = 0,
		x = -6,
	})
	self:refreshSize()
end

---@param skin rizu.skin.OsuSkinDiscovery?
function OsuManiaScoreView:setSkin(skin)
	local fonts = skin and skin.skin_ini.Fonts or {}
	---@type table<string, any>
	local typed_fonts = fonts
	local prefix, overlap_value
	for name, value in pairs(typed_fonts) do
		if type(name) == "string" then
			if name:lower() == "scoreprefix" then prefix = value end
			if name:lower() == "scoreoverlap" then overlap_value = value end
		end
	end
	prefix = prefix or "score"
	local overlap = tonumber(overlap_value) or 0
	if type(prefix) ~= "string" or prefix == "" then prefix = "score" end
	if overlap ~= overlap or overlap == math.huge or overlap == -math.huge then overlap = 0 end
	self.score_prefix = prefix
	self.score_overlap = overlap
	self:refreshSize()
end

---@return string[]
function OsuManiaScoreView:getImageAssets()
	---@type string[]
	local names = {}
	for digit = 0, 9 do names[#names + 1] = self.score_prefix .. "-" .. digit end
	for _, suffix in ipairs({"dot", "percent"}) do
		names[#names + 1] = self.score_prefix .. "-" .. suffix
	end
	return names
end

---@param suffix string
---@return love.Image?
function OsuManiaScoreView:getImage(suffix)
	return self.graphics:getFrames(self.score_prefix .. "-" .. suffix, nil)[1]
end

---@param image love.Image?
---@return number width
---@return number height
function OsuManiaScoreView:getLogicalDimensions(image)
	if not image then return 0, 0 end
	local density = self.graphics:getImageDensity(image)
	if type(density) ~= "number" or density <= 0 then density = 1 end
	return image:getWidth() / density, image:getHeight() / density
end

---@return number width
---@return number height
function OsuManiaScoreView:getTextLayout()
	local digit = self:getImage("5")
	local slot_width, digit_height = self:getLogicalDimensions(digit)
	if slot_width <= 0 then slot_width = 16 end
	local accuracy_width = 0
	local accuracy_height = digit_height
	for _, character in ipairs({"0", "0", ".", "0", "0", "%"}) do
		local suffix = character == "." and "dot" or character == "%" and "percent" or character
		local width, height = self:getLogicalDimensions(self:getImage(suffix))
		accuracy_width = accuracy_width + (character:match("%d") and slot_width or width) - self.score_overlap
		accuracy_height = math.max(accuracy_height, height)
	end

	local score_width = math.max(0, SCORE_DIGITS * (slot_width - self.score_overlap) * SCORE_SCALE)
	local score_height = digit_height * SCORE_SCALE
	local scaled_accuracy_width = math.max(0, accuracy_width * ACCURACY_SCALE)
	local scaled_accuracy_height = accuracy_height * ACCURACY_SCALE
	return math.max(score_width, scaled_accuracy_width), score_height + NEW_LAYOUT_GAP + scaled_accuracy_height
end

function OsuManiaScoreView:refreshSize()
	self.width, self.height = self:getTextLayout()
end

---@param game sphere.GameController
function OsuManiaScoreView:load(game)
	View.load(self, game)
	self:update(0, game)
end

---@param dt number
---@param game sphere.GameController
function OsuManiaScoreView:update(dt, game)
	local engine = game and game.rhythm_engine
	local score_engine = engine and engine.score_engine
	local score_source = score_engine and score_engine.scoreSource
	local accuracy_source = score_engine and score_engine.accuracySource
	---@type number?
	local score = score_source and score_source.getScore
		and score_source:getScore() * (score_source.score_multiplier or 1)
	---@type number?
	local accuracy = accuracy_source and accuracy_source.getAccuracy
		and accuracy_source:getAccuracy() * (accuracy_source.accuracy_multiplier or 1)

	self.has_score = type(score) == "number" and score == score and score ~= math.huge and score ~= -math.huge
	self.has_accuracy = type(accuracy) == "number" and accuracy == accuracy
		and accuracy ~= math.huge and accuracy ~= -math.huge
	if self.has_score and type(score) == "number" then self.target_score = score end
	if self.has_accuracy and type(accuracy) == "number" then
		self.target_accuracy = math.floor(accuracy * 100 + 0.5) / 100
	end

	local frame_ratio = math.max(0, dt) * 60
	if self.has_score then
		if math.abs(self.score - self.target_score) < 0.5 then
			self.score = self.target_score
		elseif frame_ratio > 0 then
			self.score = self.target_score + (self.score - self.target_score) * SCORE_ANIMATION_RATE ^ frame_ratio
		end
	end
	if self.has_accuracy then
		if math.abs(self.accuracy - self.target_accuracy) < 0.005 then
			self.accuracy = self.target_accuracy
		elseif frame_ratio > 0 then
			self.accuracy = self.target_accuracy
				+ (self.accuracy - self.target_accuracy) * ACCURACY_ANIMATION_RATE ^ frame_ratio
		end
	end
end

---@param value string
---@param scale number
---@param y number
---@param right_edge number
---@return number height
function OsuManiaScoreView:drawText(value, scale, y, right_edge)
	---@type rizu.skin.osu.mania.OsuManiaScoreView.Glyph[]
	local slots = {}
	local slot_width, slot_height = self:getLogicalDimensions(self:getImage("5"))
	if slot_width <= 0 then slot_width = 16 end
	local max_height = slot_height
	local total_width = 0
	for character in value:gmatch(".") do
		local suffix = character
		if character == "." then suffix = "dot"
		elseif character == "%" then suffix = "percent" end
		local image = self:getImage(suffix)
		local width, height = self:getLogicalDimensions(image)
		local digit = character:match("%d") ~= nil
		local advance = (digit and slot_width or width) - self.score_overlap
		max_height = math.max(max_height, height)
		slots[#slots + 1] = {
			image = image,
			width = width,
			height = height,
			advance = advance,
			digit = digit,
		}
		total_width = total_width + advance
	end
	local draw_x = right_edge - total_width * scale

	for _, slot in ipairs(slots) do
		if slot.image then
			local density = self.graphics:getImageDensity(slot.image)
			if type(density) ~= "number" or density <= 0 then density = 1 end
			local offset_x = slot.digit and math.max(0, (slot_width - slot.width) / 2) or 0
			local offset_y = (max_height - slot.height) / 2
			lg.setColor(1, 1, 1, 1)
			lg.draw(slot.image, draw_x + offset_x * scale, y + offset_y * scale, 0, scale / density, scale / density)
		end
		draw_x = draw_x + slot.advance * scale
	end
	return max_height * scale
end

function OsuManiaScoreView:draw()
	if not self.has_score then return end
	local score_text = ("%08d"):format(math.min(99999999, math.floor(self.score + 0.5)))
	local score_height = self:drawText(score_text, SCORE_SCALE, 0, self.width)
	if self.has_accuracy then
		local accuracy_text = ("%05.2f%%"):format(self.accuracy)
		self:drawText(accuracy_text, ACCURACY_SCALE, score_height + NEW_LAYOUT_GAP, self.width)
	end
end

return OsuManiaScoreView
