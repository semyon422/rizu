local TimingSystem = require("rizu.engine.scoring.TimingSystem")
local Subtimings = require("sea.chart.Subtimings")
local OsuManiaV1Timings = require("sea.timings.osumania.OsuManiaV1Timings_v4")
local OsuManiaV2Timings = require("sea.timings.osumania.OsuManiaV2Timings_v2")
local OsuManiaV1Score = require("rizu.engine.ScoreEngine.scores.OsuManiaV1Score")
local OsuManiaV2Score = require("rizu.engine.ScoreEngine.scores.OsuManiaV2Score")

---osu!mania. Value: overall difficulty. Subtimings: score version, V1 when missing.
---@class rizu.engine.scoring.systems.OsuMania : rizu.engine.scoring.TimingSystem
---@operator call: rizu.engine.scoring.systems.OsuMania
local OsuMania = TimingSystem + {}

OsuMania.name = "osuod"
OsuMania.healths_name = "simple"
OsuMania.label = "osu!mania"
OsuMania.normalscore = false
OsuMania.grade_scale = "osuod"
OsuMania.default_subtimings = Subtimings("scorev", 1)
OsuMania.range = {min = 0, max = 10, step = 0.1}
OsuMania.default_value = 8
OsuMania.score_versions = {1, 2}

---@param value number
function OsuMania:formatValue(value)
	return ("OD %g"):format(value)
end

---@param timings sea.Timings
---@param subtimings sea.Subtimings?
function OsuMania:getName(timings, subtimings)
	return ("osu!mania V%i OD%g"):format((subtimings or self.default_subtimings).data, timings.data)
end

---ScoreV2 takes the nearest note, ScoreV1 the earliest.
---@param subtimings sea.Subtimings?
function OsuMania:isNearest(subtimings)
	return (subtimings or self.default_subtimings).data == 2
end

---@param subtimings sea.Subtimings?
function OsuMania:acceptsSubtimings(subtimings)
	return not subtimings or subtimings.name == "scorev" and (subtimings.data == 1 or subtimings.data == 2)
end

---@param timings sea.Timings
---@param subtimings sea.Subtimings
function OsuMania:newTimingValues(timings, subtimings)
	local preset = subtimings.data == 2 and OsuManiaV2Timings or OsuManiaV1Timings
	return preset:getTimingValues(timings.data)
end

---@param timings sea.Timings
---@param subtimings sea.Subtimings
---@param healths sea.Healths? Other kinds than simple mean the chart's own HP.
function OsuMania:newScoreSystems(timings, subtimings, healths)
	local Score = subtimings.data == 2 and OsuManiaV2Score or OsuManiaV1Score
	return {Score(timings.data, healths and healths.name == "simple" and healths or nil)}
end

---@param subtimings sea.Subtimings?
function OsuMania:getAccuracyClass(subtimings)
	return subtimings and subtimings.data == 2 and OsuManiaV2Score or OsuManiaV1Score
end

---@param accuracy number
function OsuMania:getGrade(accuracy)
	if accuracy == 1 then
		return "SS"
	elseif accuracy > 0.95 then
		return "S"
	elseif accuracy > 0.9 then
		return "A"
	elseif accuracy > 0.8 then
		return "B"
	elseif accuracy > 0.7 then
		return "C"
	end
	return "D"
end

return OsuMania()
