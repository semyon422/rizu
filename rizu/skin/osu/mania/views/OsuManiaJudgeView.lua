local View = require("rizu.skin.View")
local OsuImage = require("rizu.skin.osu.OsuImage")

local lg = love.graphics
local JUDGE_ASSETS = {"300g", "300", "200", "100", "50", "0"}
local JUDGE_SCALE = 480 / 768
local DURATION = 0.22

---@class rizu.skin.osu.mania.views.OsuManiaJudgeView : rizu.skin.View
---@operator call: rizu.skin.osu.mania.views.OsuManiaJudgeView
---@field graphics rizu.skin.osu.OsuSkinGraphics
---@field elapsed number
---@field duration number
---@field sequence_index integer
---@field score_engine rizu.ScoreEngine?
---@field image rizu.skin.osu.OsuSkinGraphics.Image?
---@field frames rizu.skin.osu.OsuSkinGraphics.Image[]
---@field rotation number
---@field grade integer
---@field section rizu.skin.OsuSkinIni.ManiaSection
local OsuManiaJudgeView = View + {}

---@param graphics rizu.skin.osu.OsuSkinGraphics
function OsuManiaJudgeView:new(graphics)
	self.graphics = graphics
	self.elapsed = DURATION
	self.duration = DURATION
	self.sequence_index = 0
	self.score_engine = nil
	self.image = nil
	self.frames = {}
	self.rotation = 0
	self.grade = 1
	self.section = {}
	View.new(self, {anchor = "top", origin = "center", x = 0, y = 325, width = 0, height = 0})
end

---@param _skin rizu.skin.OsuSkinDiscovery?
---@param section rizu.skin.OsuSkinIni.ManiaSection?
function OsuManiaJudgeView:setSkin(_skin, section)
	self.section = section or {}
	local position = tonumber(self.section.ScorePosition)
	if position == nil or position ~= position or position == math.huge or position == -math.huge then position = 325 end
	if self.section.UpsideDown == "1" or self.section.UpsideDown == "true" then position = 480 - position end
	self.y = math.max(0, math.min(480, position))
end

---@return {name: string?, fallback: string}[]
function OsuManiaJudgeView:getImageAssets()
	local assets = {}
	for _, grade in ipairs(JUDGE_ASSETS) do
		local custom = self.section["Hit" .. grade]
		if custom and tonumber(custom) then custom = nil end
		assets[#assets + 1] = {name = custom or ("mania-hit" .. grade), fallback = custom and ("mania-hit" .. grade) or nil}
	end
	return assets
end

---@param judge integer
---@param source rizu.IJudgesSource
---@return integer?
local function get_grade(judge, source)
	local names = source.getJudgeNames and source:getJudgeNames()
	if judge < 0 and names then judge = #names + judge + 1 end
	if not names or not names[judge] then return nil end
	local name = names[judge]:lower()
	if name:find("miss", 1, true) or name:find("poor", 1, true) then return 6 end
	if name:find("perfect", 1, true) or name:find("marvelous", 1, true) or name == "pgreat" then return 1 end
	if name:find("great", 1, true) then return 2 end
	if name:find("good", 1, true) or name:find("200", 1, true) then return 3 end
	if name == "ok" or name == "100" or name == "bad" then return 4 end
	if name == "meh" or name == "50" or name == "boo" then return 5 end
	return math.max(1, math.min(6, judge))
end

---@param game sphere.GameController
function OsuManiaJudgeView:load(game)
	View.load(self, game)
	self.sequence_index = 0
	self.score_engine = nil
end

---@param game sphere.GameController?
function OsuManiaJudgeView:unload(game)
	self.image = nil
	self.frames = {}
	self.elapsed = self.duration
	View.unload(self, game)
end

---@param dt number
---@param game sphere.GameController
function OsuManiaJudgeView:update(dt, game)
	local engine = game and game.rhythm_engine
	local score_engine = engine and engine.score_engine
	local sequence = score_engine and score_engine.sequence
	local source = score_engine and score_engine.judgesSource
	if not score_engine or not sequence or not source then
		self.elapsed = self.duration
		self.sequence_index = 0
		self.score_engine = score_engine
		return
	end
	if score_engine ~= self.score_engine then
		self.score_engine = score_engine
		self.sequence_index = 0
		self.elapsed = self.duration
	end
	self.elapsed = math.min(self.duration, self.elapsed + math.max(0, dt))
	local latest_index = #sequence
	for index = self.sequence_index + 1, latest_index do
		local slice = sequence[index]
		local judgement = slice and slice[source:getKey()]
		local judge = judgement and (judgement.visual_judge or judgement.judge_index or judgement.last_judge)
		local grade = judge and get_grade(judge, source)
		if grade then
			local asset = self.section["Hit" .. JUDGE_ASSETS[grade]]
			if asset and tonumber(asset) then asset = nil end
			local frames = self.graphics:getAnimationFrames(asset, "mania-hit" .. JUDGE_ASSETS[grade], "playfield")
			self.frames = frames
			self.image = frames[1]
			if self.image then
				self.width, self.height = OsuImage.dimensions(self.image)
				self.elapsed = 0
				self.rotation = grade == 6 and (math.random() - 0.5) * 0.2 or 0
				self.grade = grade
			end
		end
	end
	self.sequence_index = latest_index
end

function OsuManiaJudgeView:draw()
	if not self.image or self.elapsed >= self.duration then return end
	local progress = self.elapsed / self.duration
	local alpha = progress < 0.08 and progress / 0.08 or (progress > 0.82 and (1 - progress) / 0.18 or 1)
	local scale
	if self.grade == 6 then scale = 1.2 - 0.2 * math.min(1, self.elapsed / 0.1)
	elseif self.elapsed < 0.08 then scale = 0.8 + 0.2 * self.elapsed / 0.08
	elseif self.elapsed < 0.18 then scale = 1 - 0.3 * (self.elapsed - 0.08) / 0.1
	else scale = 0.7 - 0.3 * (self.elapsed - 0.18) / 0.04 end
	local frame = self.frames[math.min(#self.frames, math.floor(self.elapsed * 20) + 1)] or self.image
	lg.setColor(1, 1, 1, math.max(0, alpha))
	local draw_scale = scale * JUDGE_SCALE
	local width, height = OsuImage.dimensions(frame)
	local batch = frame.texture and frame.batch
	OsuImage.draw(frame, self.width / 2, self.height / 2, self.rotation, draw_scale, draw_scale,
		width / 2, height / 2)
	if batch then batch:flush() end
end

return OsuManiaJudgeView
