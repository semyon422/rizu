local class = require("class")

---@class rizu.JudgeAccuracy
---@operator call: rizu.JudgeAccuracy
local JudgeAccuracy = class()

---@param weights number[]
function JudgeAccuracy:new(weights)
	self.weights = weights
end

---@param judges integer[]
function JudgeAccuracy:get(judges)
	local weights = self.weights

	local score = 0
	local max_score = 0
	for i, count in ipairs(judges) do
		score = score + (weights[i] or 0) * count
		max_score = max_score + (weights[1] or 1) * count
	end

	if max_score == 0 then
		return 0
	end

	return score / max_score
end

return JudgeAccuracy
