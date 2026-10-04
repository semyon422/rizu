local View = require("rizu.skin.View")
local OsuManiaBitmapFont = require("rizu.skin.osu.mania.OsuManiaBitmapFont")

local ACCURACY_SCALE = 0.96 * 0.625 * 0.6
local GAP = 3

---@class rizu.skin.osu.mania.views.OsuManiaAccuracyView : rizu.skin.View
---@operator call: rizu.skin.osu.mania.views.OsuManiaAccuracyView
---@field bitmap_font rizu.skin.osu.mania.OsuManiaBitmapFont
---@field accuracy number
---@field target_accuracy number
---@field display_text string
---@field display_value number?
---@field has_accuracy boolean
local OsuManiaAccuracyView = View + {}

---@param graphics rizu.skin.osu.mania.OsuManiaSkinGraphics
function OsuManiaAccuracyView:new(graphics)
	self.bitmap_font = OsuManiaBitmapFont(graphics)
	self.accuracy = 0
	self.target_accuracy = 0
	self.display_text = "00.00%"
	self.display_value = nil
	self.has_accuracy = false
	View.new(self, {anchor = "top_right", origin = "top_right", x = -6, width = 0, height = 0})
	self:setSkin(nil, 0)
end

---@param skin rizu.skin.OsuSkinDiscovery?
---@param score_height number
function OsuManiaAccuracyView:setSkin(skin, score_height)
	self.bitmap_font:setSkin(skin, "Score")
	self.y = score_height + GAP
	local width, height = self.bitmap_font:measure("00.00%")
	self.width = width * ACCURACY_SCALE
	self.height = height * ACCURACY_SCALE
end

---@return string[]
function OsuManiaAccuracyView:getImageAssets()
	return self.bitmap_font:getImageAssets()
end

---@param game sphere.GameController
function OsuManiaAccuracyView:load(game)
	View.load(self, game)
	self:update(0, game)
end

---@param dt number
---@param game sphere.GameController
function OsuManiaAccuracyView:update(dt, game)
	local engine = game and game.rhythm_engine
	local score_engine = engine and engine.score_engine
	local source = score_engine and score_engine.accuracySource
	local accuracy = source and source.getAccuracy
		and source:getAccuracy() * (source.accuracy_multiplier or 1)
	self.has_accuracy = type(accuracy) == "number" and accuracy == accuracy
		and accuracy ~= math.huge and accuracy ~= -math.huge
	if not self.has_accuracy then return end
	self.target_accuracy = math.floor(accuracy * 100 + 0.5) / 100
	local frame_ratio = math.max(0, dt) * 60
	if math.abs(self.accuracy - self.target_accuracy) < 0.005 then
		self.accuracy = self.target_accuracy
	elseif frame_ratio > 0 then
		self.accuracy = self.target_accuracy + (self.accuracy - self.target_accuracy) * 0.5 ^ frame_ratio
	end
	local display_value = math.floor(self.accuracy * 100 + 0.5) / 100
	if self.display_value ~= display_value then
		self.display_value = display_value
		self.display_text = ("%05.2f%%"):format(display_value)
	end
end

function OsuManiaAccuracyView:draw()
	if not self.has_accuracy then return end
	self.bitmap_font:draw(self.display_text, ACCURACY_SCALE, 0, self.width)
end

return OsuManiaAccuracyView
