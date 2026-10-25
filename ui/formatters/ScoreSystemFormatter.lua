local class = require("class")
local Scoring = require("rizu.engine.scoring.Scoring")

---Colors and judge names of a score system. Its name and grades come from rizu.engine.scoring.Scoring.
---@class ui.formatters.ScoreSystemFormatter
---@operator call: ui.formatters.ScoreSystemFormatter
local ScoreSystemFormatter = class()

local fallback_grade_color = {0.51, 0.37, 0, 1}
local fallback_judge_color = {0.65, 0.7, 0.8, 1}
local miss_color = {1, 0.1, 0.18, 1}

local judge_colors = {
	{0, 0.7, 1, 1},
	{1, 0.82, 0, 1},
	{0, 0.9, 0.5, 1},
	{0.3, 0.55, 1, 1},
	{0.85, 0, 0.85, 1},
}

local grade_colors = {
	sphere = {
		SSSSS = {1, 1, 1, 1},
		SSSS = {1, 1, 1, 1},
		SSS = {1, 1, 1, 1},
		SS = {0.6, 0.8, 1, 1},
		S = {0.95, 0.796, 0.188, 1},
		A = {0.07, 0.8, 0.56, 1},
		B = {0.1, 0.39, 1, 1},
		C = {1, 0.1, 0.7, 1},
		D = fallback_grade_color,
	},
	osuod = {
		SS = {0.6, 0.8, 1, 1},
		S = {0.95, 0.796, 0.188, 1},
		A = {0.07, 0.8, 0.56, 1},
		B = {0.1, 0.39, 1, 1},
		C = {0.42, 0.48, 0.51, 1},
		D = fallback_grade_color,
	},
	etternaj = {
		AAAAA = {1, 1, 1, 1},
		AAAA = {0.6, 0.8, 1, 1},
		AAA = {0.95, 0.796, 0.188, 1},
		AA = {0.07, 0.8, 0.56, 1},
		A = {0, 0.7, 0.32, 1},
		B = {0.1, 0.7, 1, 1},
		C = {1, 0.1, 0.7, 1},
		F = fallback_grade_color,
	},
	quaver = {
		X = {0.6, 0.8, 1, 1},
		S = {0.95, 0.796, 0.188, 1},
		A = {0.95, 0.796, 0.188, 1},
		B = {0.07, 0.8, 0.56, 1},
		C = {0.1, 0.39, 1, 1},
		D = {0.42, 0.48, 0.51, 1},
		F = fallback_grade_color,
	},
	bmsrank = {
		AAA = {0.95, 0.796, 0.188, 1},
		AA = {0.07, 0.8, 0.56, 1},
		A = {0, 0.7, 0.32, 1},
		B = {0.1, 0.7, 1, 1},
		C = {1, 0.1, 0.7, 1},
		E = {1, 0.1, 0.7, 1},
		F = fallback_grade_color,
	},
	iidx = {
		AAA = {0.95, 0.796, 0.188, 1},
		AA = {0.07, 0.8, 0.56, 1},
		A = {0, 0.7, 0.32, 1},
		B = {0.1, 0.7, 1, 1},
		C = {1, 0.1, 0.7, 1},
		D = fallback_grade_color,
		E = {1, 0.1, 0.7, 1},
		F = fallback_grade_color,
	},
}

---@param score_system rizu.ScoreSystem
function ScoreSystemFormatter:new(score_system)
	self.score_system = score_system
end

---@param score_system rizu.ScoreSystem
function ScoreSystemFormatter:setScoreSystem(score_system)
	self.score_system = score_system
end

---@return rizu.engine.scoring.Scoring?
function ScoreSystemFormatter:getScoring()
	local timings = self.score_system.timings
	return timings and Scoring(timings, self.score_system.subtimings)
end

---@return string
function ScoreSystemFormatter:getName()
	local scoring = self:getScoring()
	return scoring and scoring:getName() or "No timings"
end

---@param accuracy number
---@return string
function ScoreSystemFormatter:getGrade(accuracy)
	local scoring = self:getScoring()
	return scoring and scoring:getGrade(accuracy) or "F"
end

---@param grade string
---@return gui.Color
function ScoreSystemFormatter:getGradeColor(grade)
	local scoring = self:getScoring()
	local colors = scoring and grade_colors[scoring.system.grade_scale]
	return colors and colors[grade] or fallback_grade_color
end

---@param index integer
---@return string
function ScoreSystemFormatter:getJudgeName(index)
	---@cast self.score_system +rizu.IJudgesSource
	local name = self.score_system:getJudgeNames()[index]
	if not name then
		return ("Judge %d"):format(index)
	end
	return name:sub(1, 1):upper() .. name:sub(2)
end

---@param index integer
---@return gui.Color
function ScoreSystemFormatter:getJudgeColor(index)
	---@cast self.score_system +rizu.IJudgesSource
	if index == #self.score_system:getJudgeNames() then
		return miss_color
	end
	return judge_colors[index] or fallback_judge_color
end

return ScoreSystemFormatter
