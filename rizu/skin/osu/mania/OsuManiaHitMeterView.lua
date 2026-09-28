local View = require("rizu.skin.View")

local lg = love.graphics
local ICON_SIZE = 9 * 1.6
local ICON_GAP = 1.6
local FADE_DELAY = 4
local FADE_RATE = 2.4
local COLORS = {
	{0.20, 0.74, 0.91}, {0.34, 0.89, 0.08}, {0.85, 0.68, 0.27},
	{0.12, 0.41, 0.78}, {0.43, 0.47, 0.53}, {1, 0.035, 0.035},
}

---@class rizu.skin.osu.mania.OsuManiaHitMeterView : rizu.skin.View
---@operator call: rizu.skin.osu.mania.OsuManiaHitMeterView
---@field sequence_index integer
---@field score_engine rizu.ScoreEngine?
---@field last_hit_time number
---@field icon_index integer
---@field icons {color: number[], alpha: number}[]
local OsuManiaHitMeterView = View + {}

function OsuManiaHitMeterView:new()
	self.sequence_index = 0
	self.score_engine = nil
	self.last_hit_time = -math.huge
	self.icon_index = 0
	self.icons = {}
	for _ = 1, 14 do self.icons[#self.icons + 1] = {color = COLORS[1], alpha = 0} end
	View.new(self, {anchor = "bottom", origin = "bottom", x = 0, y = -4,
		width = #self.icons * (ICON_SIZE + ICON_GAP), height = ICON_SIZE})
end

---@param game sphere.GameController
function OsuManiaHitMeterView:load(game)
	View.load(self, game)
	self.sequence_index = 0
	self.score_engine = nil
	self.last_hit_time = -math.huge
	self.icon_index = 0
	for _, icon in ipairs(self.icons) do icon.alpha = 0 end
end

---@param dt number
---@param game sphere.GameController
function OsuManiaHitMeterView:update(dt, game)
	local engine = game and game.rhythm_engine
	local score_engine = engine and engine.score_engine
	local sequence = score_engine and score_engine.sequence
	local source = score_engine and score_engine.judgesSource
	if score_engine ~= self.score_engine then
		self.score_engine = score_engine
		self.sequence_index = 0
		for _, icon in ipairs(self.icons) do icon.alpha = 0 end
	end
	if sequence and source then
		for index = self.sequence_index + 1, #sequence do
			local slice = sequence[index]
			local judgement = slice and slice[source:getKey()]
			local judge = judgement and (judgement.visual_judge or judgement.judge_index or judgement.last_judge)
			if judge then
				local names = source.getJudgeNames and source:getJudgeNames()
				if judge < 0 and names then judge = #names + judge + 1 end
				local name = names and names[judge]
				local grade
				if name then
					name = name:lower()
					if name:find("miss", 1, true) or name:find("poor", 1, true) or name == "0" then
						grade = 6
					elseif name:find("perfect", 1, true) or name:find("marvelous", 1, true) or name == "pgreat" then
						grade = 1
					elseif name:find("great", 1, true) then
						grade = 2
					elseif name:find("good", 1, true) or name == "200" then
						grade = 3
					elseif name == "ok" or name == "100" or name == "bad" then
						grade = 4
					else
						grade = 5
					end
				end
				if grade then
					for _, icon in ipairs(self.icons) do icon.alpha = math.max(0, icon.alpha - 0.08) end
					self.icon_index = self.icon_index % #self.icons + 1
					local icon = self.icons[self.icon_index]
					icon.color = COLORS[grade]
					icon.alpha = 1
					self.last_hit_time = 0
				end
			end
		end
		self.sequence_index = #sequence
	end
	self.last_hit_time = self.last_hit_time + math.max(0, dt)
	if self.last_hit_time > FADE_DELAY then
		local alpha = math.max(0, 1 - dt * FADE_RATE)
		for _, icon in ipairs(self.icons) do icon.alpha = icon.alpha * alpha end
	end
end

function OsuManiaHitMeterView:draw()
	local x = 0
	local previous_mode, previous_alpha = lg.getBlendMode()
	lg.setBlendMode("add", "alphamultiply")
	for _, icon in ipairs(self.icons) do
		if icon.alpha > 0 then
			lg.setColor(icon.color[1], icon.color[2], icon.color[3], icon.alpha * 0.8)
			lg.rectangle("fill", x, 0, ICON_SIZE, ICON_SIZE)
		end
		x = x + ICON_SIZE + ICON_GAP
	end
	lg.setBlendMode(previous_mode, previous_alpha)
end

return OsuManiaHitMeterView
