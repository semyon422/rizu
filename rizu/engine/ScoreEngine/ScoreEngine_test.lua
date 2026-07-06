local ScoreEngine = require("rizu.engine.ScoreEngine")
local ScoreEngineFactory = require("rizu.engine.ScoreEngine.ScoreEngineFactory")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")

local test = {}

---@param t testing.T
function test.qwe(t)
	local se = ScoreEngine()
	se.judgement = "soundsphere"

	se:load({notes_count = 0})

	local factory = ScoreEngineFactory()
	local systems = assert(factory:get(Timings("osuod", 8.5), Subtimings("scorev", 2)))
	local osu_od85_v2 = systems[1]

	se:addScoreSystem(osu_od85_v2)
	se:select(osu_od85_v2:getKey())

	t:eq(se.accuracySource, osu_od85_v2)
	t:eq(se.judgesSource, osu_od85_v2)

	t:eq(se.accuracySource:getAccuracyString(), "0.00%")

	-- local acc = se:getAccuracy()
	-- local score = se:getScore()
end

return test
