local View = require("rizu.skin.View")
local OsuManiaBitmapFont = require("rizu.skin.osu.mania.OsuManiaBitmapFont")

local SCORE_DIGITS = 8
local SCORE_SCALE = 0.96 * 0.625
local SCORE_ANIMATION_RATE = 0.75

---@class rizu.skin.osu.mania.OsuManiaScoreView : rizu.skin.View
---@operator call: rizu.skin.osu.mania.OsuManiaScoreView
---@overload fun(graphics: rizu.skin.osu.mania.OsuManiaSkinGraphics): rizu.skin.osu.mania.OsuManiaScoreView
---@field graphics rizu.skin.osu.mania.OsuManiaSkinGraphics
---@field bitmap_font rizu.skin.osu.mania.OsuManiaBitmapFont
---@field score_prefix string
---@field score_overlap number
---@field score number
---@field target_score number
---@field has_score boolean
local OsuManiaScoreView = View + {}

---@param graphics rizu.skin.osu.mania.OsuManiaSkinGraphics
function OsuManiaScoreView:new(graphics)
	assert(type(graphics) == "table", "osu mania score view requires skin graphics")
	self.graphics = graphics
	self.bitmap_font = OsuManiaBitmapFont(graphics)
	self.score_prefix = self.bitmap_font.prefix
	self.score_overlap = self.bitmap_font.overlap
	self.score = 0
	self.target_score = 0
	self.has_score = false
	View.new(self, {anchor = "top_right", origin = "top_right", width = 0, height = 0, x = -6})
	self:refreshSize()
end

---@param skin rizu.skin.OsuSkinDiscovery?
function OsuManiaScoreView:setSkin(skin)
	self.bitmap_font:setSkin(skin, "Score")
	self.score_prefix = self.bitmap_font.prefix
	self.score_overlap = self.bitmap_font.overlap
	self:refreshSize()
end

---@return string[]
function OsuManiaScoreView:getImageAssets()
	return self.bitmap_font:getImageAssets()
end

---@return number width
---@return number height
function OsuManiaScoreView:getTextLayout()
	local width, height = self.bitmap_font:measure(string.rep("0", SCORE_DIGITS))
	return width * SCORE_SCALE, height * SCORE_SCALE
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
	local source = score_engine and score_engine.scoreSource
	local score = source and source.getScore and source:getScore() * (source.score_multiplier or 1)
	self.has_score = type(score) == "number" and score == score and score ~= math.huge and score ~= -math.huge
	if not self.has_score then return end
	---@cast score number
	self.target_score = score
	local frame_ratio = math.max(0, dt) * 60
	if math.abs(self.score - self.target_score) < 0.5 then
		self.score = self.target_score
	elseif frame_ratio > 0 then
		self.score = self.target_score + (self.score - self.target_score) * SCORE_ANIMATION_RATE ^ frame_ratio
	end
end

function OsuManiaScoreView:draw()
	if not self.has_score then return end
	local text = ("%08d"):format(math.min(99999999, math.floor(self.score + 0.5)))
	self.bitmap_font:draw(text, SCORE_SCALE, 0, self.width)
end

return OsuManiaScoreView
