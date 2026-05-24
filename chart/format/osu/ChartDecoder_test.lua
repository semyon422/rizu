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

function test.empty_timings(t)
	local dec = ChartDecoder()
	local charts = dec:decode(empty_timings_chart)
end

return test
