local ChartDecoder = require("chart.format.osu.ChartDecoder")

local test = {}

local test_chart = [[
osu file format v14

[General]
Mode: 3
PreviewTime: 0

[Difficulty]
CircleSize:4

[Events]
5,1000,0,"sample1.wav",100

[TimingPoints]
0,500,4,2,0,70,1,0
1000,-200,4,2,0,80,0,0


[HitObjects]
320,0,0,128,0,1000:1:0:0:0:
64,192,1000,5,6,0:0:0:0:]]

---@param t testing.T
function test.basic(t)
	local dec = ChartDecoder()
	local charts = dec:decode(test_chart)
end

local empty_chart = [[
osu file format v14

[General]
Mode: 3
PreviewTime: 0

[Difficulty]
CircleSize:4
]]

---@param t testing.T
function test.empty(t)
	local dec = ChartDecoder()
	local charts = dec:decode(empty_chart)
end

local empty_timings_chart = [[
osu file format v14

[General]
Mode: 3
PreviewTime: 0

[Difficulty]
CircleSize:4

[HitObjects]
320,0,0,128,0,1000:1:0:0:0:
64,192,1000,5,6,0:0:0:0:]]

---@param t testing.T
function test.empty_timings(t)
	local dec = ChartDecoder()
	local charts = dec:decode(empty_timings_chart)
end

---@param t testing.T
function test.invalid_timing_point(t)
	local dec = ChartDecoder()
	local source = empty_timings_chart:gsub("%[HitObjects%]", "[TimingPoints]\n0,0,4,2,0,70,1,0\n\n[HitObjects]")
	local charts = dec:decode(source)
	t:eq(#charts, 1)
	t:eq(charts[1].chartmeta.tempo, 0)
	t:eq(charts[1].chartmeta.inputmode, "4key")
end

return test
