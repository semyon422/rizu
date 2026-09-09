local ChartDecoder = require("chart.format.osu.ChartDecoder")
local RefChart = require("chart.refchart.RefChart")
local Restorer = require("chart.refchart.Restorer")
local test = {}

local data = [[osu file format v14
[General]
Mode:2
[Difficulty]
CircleSize:5
OverallDifficulty:5
SliderMultiplier:1
SliderTickRate:1
[TimingPoints]
0,500,4,1,0,100,1,0
[HitObjects]
100,100,1000,1,0,0:0:0:0:
100,100,2000,2,0,L|300:100,2,200
256,192,5000,8,0,6000,0:0:0:0:
]]

---@param t testing.T
function test.native_objects_and_deterministic_showers_survive_snapshot(t)
	local chart = ChartDecoder():decode(data)[1].chart
	t:eq(chart.aim, nil)
	t:eq(tostring(chart.inputMode), "1fruits")
	t:tdeq(chart.catch, ChartDecoder():decode(data)[1].chart.catch)
	local counts = {fruit = 0, droplet = 0, tiny = 0, banana = 0}
	local time = -math.huge
	for _, object in ipairs(chart.catch.objects) do
		counts[object.kind] = counts[object.kind] + 1
		t:assert(object.time >= time)
		t:assert(object.x >= 0 and object.x <= 512)
		time = object.time
	end
	t:eq(counts.fruit, 4)
	t:eq(counts.droplet, 2)
	t:eq(counts.tiny, 28)
	t:eq(counts.banana, 17)
	t:tdeq(Restorer():restore(RefChart(chart)).catch, chart.catch)
end

return test
