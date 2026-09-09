local ChartDecoder = require("chart.format.osu.ChartDecoder")
local AimChart = require("chart.format.osu.AimChart")
local RefChart = require("chart.refchart.RefChart")
local Restorer = require("chart.refchart.Restorer")

local test = {}

local header = [[osu file format v14
[General]
Mode:0
PreviewTime:0
[Difficulty]
CircleSize:4
OverallDifficulty:6
ApproachRate:7
[TimingPoints]
0,500,4,2,0,70,1,0
[HitObjects]
]]

---@param t testing.T
function test.positions_settings_and_same_time_objects_survive_refchart(t)
	local chart = ChartDecoder():decode(header .. "100,192,1000,1,0,0:0:0:0:\n400,100,1000,1,0,0:0:0:0:")[1].chart
	local restored = Restorer():restore(RefChart(chart))
	t:eq(tostring(restored.inputMode), "1osu")
	t:tdeq(restored.aim, chart.aim)
	t:eq(#restored.aim.objects, 2)
	t:eq(restored.aim.objects[2].x, 400)
	t:eq(restored.aim.circle_size, 4)
	t:eq(restored.aim.approach_rate, 7)
	t:eq(restored.aim.overall_difficulty, 6)
	t:eq(AimChart.isSupported(restored.aim), true)
end

---@param t testing.T
function test.unsupported_objects_are_preserved_and_rejected(t)
	for _, line in ipairs({
		"100,192,1000,2,0,L|300:192,1,200",
		"256,192,1000,8,0,2000,0:0:0:0:",
	}) do
		local chart = ChartDecoder():decode(header .. line)[1].chart
		t:eq(#chart.aim.objects, 1)
		local ok, err = AimChart.isSupported(chart.aim)
		t:eq(ok, false)
		t:assert(err:find("circles only", 1, true))
	end
end

return test
