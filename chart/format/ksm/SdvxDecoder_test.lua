local ModeNotes = require("chart.model.ModeNotes")
local GameplayChart = require("rizu.gameplay.GameplayChart")
local ReplayBase = require("sea.replays.ReplayBase")
local Restorer = require("chart.refchart.Restorer")
local ChartDecoder = require("chart.format.ksm.ChartDecoder")
local test = {}
local source = [[title=fixture
artist=test
effect=test
difficulty=light
level=5
t=120
m=music.ogg
o=125
po=1000
--
2000|20|0o
2000|00|::
0000|00|o0
0000|00|--
--
]]

---@param t testing.T
function test.worker_preserves_native_geometry_and_audio(t)
	local compute = assert(loadstring(string.dump(GameplayChart.compute)))
	local result = compute({chartfile_name = "test.ksh", index = 1}, source, nil, ReplayBase(), {})
	t:eq(result.error, nil)
	t:eq(result.chartmeta.title, "fixture")
	t:eq(result.chartmeta.audio_path, "music.ogg")
	t:eq(result.chartmeta.preview_time, 1)
	t:eq(result.chartdiff.duration, 1)
	t:eq(result.chartdiff.osu_diff, nil)
	local restored = Restorer():restore(result.refchart)
	local direct = ChartDecoder():decode(source, ("a"):rep(32))[1].chart
	t:tdeq(ModeNotes.read(restored, "sdvx"), ModeNotes.read(direct, "sdvx"))
	t:eq(#ModeNotes.read(restored, "sdvx").lasers, 2)
	local audio = restored.layers.audio:getPointList()[1]
	t:eq(audio.absoluteTime, -0.125)
end

---@param t testing.T
function test.music_gain_can_exceed_one(t)
	local chart = ChartDecoder():decode((source:gsub("m=music.ogg", "m=music.ogg\nmvol=125")), ("a"):rep(32))[1].chart
	for _, note in chart.notes:iter() do
		if note.column == "audio" then t:eq(note.data.sounds[1][2], 1.25); return end
	end
	error("missing audio note")
end

return test
