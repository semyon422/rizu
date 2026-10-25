local Scoring = require("rizu.engine.scoring.Scoring")
local ScoreEngine = require("rizu.engine.ScoreEngine")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")

local test = {}

---@param t testing.T
function test.osu_defaults_to_score_v1(t)
	local scoring = Scoring(Timings("osuod", 8.5))
	t:eq(scoring:getName(), "osu!mania V1 OD8.5")
	local timings, subtimings = scoring:encode()
	t:eq(timings, 2185)
	t:eq(subtimings, 1101)
	t:eq(Scoring(Timings("osuod", 8.5), Subtimings("scorev", 2)):getName(), "osu!mania V2 OD8.5")
end

---@param t testing.T
function test.names_formats_and_grades(t)
	t:eq(Scoring(Timings("etternaj", 4)):getName(), "Etterna J4")
	t:eq(Scoring(Timings("bmsrank", 3)):getName(), "LR2 Easy")
	t:eq(Scoring(Timings("quaver")):getName(), "Quaver standard")
	t:eq(Scoring(Timings("simple", 0.1)):getName(), "Simple 100ms")

	t:eq(Scoring(Timings("osuod", 8)):formatAccuracy(0.98765), "98.77%")
	t:eq(Scoring(Timings("osuod", 8)):getGrade(0.96), "S")
	t:eq(Scoring(Timings("etternaj", 4)):getGrade(0.998), "AAA")
	t:eq(Scoring(Timings("iidx")):getGrade(8 / 9), "AAA")
end

---@param t testing.T
function test.rizu_simple_and_arbitrary_use_normalscore(t)
	for _, timings in ipairs({Timings("sphere"), Timings("simple", 0.1), Timings("arbitrary")}) do
		local scoring = Scoring(timings)
		t:assert(scoring:isNormalscore())
		t:eq(scoring:formatAccuracy(0.021), "21.00ms")
		t:eq(scoring:getGrade(0.01), "S")
	end
	t:assert(not Scoring(Timings("osuod", 8)):isNormalscore())
end

---@param t testing.T
function test.accuracy_source_of_the_engine(t)
	local se = ScoreEngine()
	se:load({notes_count = 1} --[[@as any]])
	t:eq(Scoring(Timings("sphere")):getAccuracySource(se), se.scores.normalscore)
	local source = assert(Scoring(Timings("etternaj", 4)):getAccuracySource(se))
	t:eq((source --[[@as rizu.ScoreSystem]]):getKey(), "etterna_accuracy_j4")
end

---@param t testing.T
function test.invalid_pairs(t)
	t:eq(select(2, TimingValuesFactory:get(Timings("etternaj", 4), Subtimings("scorev", 1))),
		"invalid timings-subtimings pair")
	t:eq(select(2, TimingValuesFactory:get(Timings("arbitrary"))), "undefined for arbitrary timings")
	t:assert(TimingValuesFactory:get(Timings("osuod", 8), Subtimings("scorev", 2)))
	t:eq(Scoring(Timings("etternaj", 4), Subtimings("scorev", 1)):createScoreSystems(), nil)
end

return test
