local GameplayTimings = require("rizu.gameplay.GameplayTimings")
local ReplayBase = require("sea.replays.ReplayBase")
local Chartmeta = require("sea.chart.Chartmeta")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")

local test = {}

---@param t testing.T
function test.chart_timings_replace_the_picked_ones(t)
	local replayBase = ReplayBase()
	local chartmeta = Chartmeta()
	replayBase.timings = Timings("osuod", 5)
	replayBase.nearest = true
	chartmeta.timings = Timings("osuod", 10)

	GameplayTimings(chartmeta):apply(replayBase)

	t:eq(replayBase.timings, nil)
	t:eq(replayBase.subtimings, Subtimings("scorev", 1))
	t:eq(replayBase.nearest, false)
end

---@param t testing.T
function test.iidx_format_uses_iidx_timings(t)
	local replayBase = ReplayBase()
	local chartmeta = Chartmeta()
	chartmeta.format = "iidx"

	GameplayTimings(chartmeta):apply(replayBase)

	t:eq(replayBase.timings, Timings("iidx"))
	t:eq(replayBase.subtimings, nil)
	local timing_values = replayBase.timing_values
	t:eq(timing_values.ShortNote.hit[1], -0.25)
	t:eq(timing_values.ShortNote.hit[2], 0.25)
	t:eq(timing_values.LongNoteStart.hit[1], -0.25)
	t:eq(timing_values.LongNoteStart.hit[2], 0.25)
	t:eq(timing_values.LongNoteEnd.hit[1], -0.25)
	t:eq(timing_values.LongNoteEnd.hit[2], 0.25)
end

---@param t testing.T
function test.stepmania_is_etterna_j4_with_nearest(t)
	local replayBase = ReplayBase()
	local chartmeta = Chartmeta()
	replayBase.timings = Timings("osuod", 9)
	chartmeta.format = "stepmania"

	GameplayTimings(chartmeta):apply(replayBase)

	t:eq(replayBase.timings, Timings("etternaj", 4)) -- always not nil if chartmeta.timings is nil
	t:eq(replayBase.subtimings, nil)
	t:eq(replayBase.nearest, true)
end

return test
