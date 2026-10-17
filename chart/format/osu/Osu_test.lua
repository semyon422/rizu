local RawOsu = require("chart.format.osu.RawOsu")
local Osu = require("chart.format.osu.Osu")

local test = {}

local test_chart = [[
osu file format v14

[General]
Mode: 3

[Difficulty]
CircleSize:4

[Events]
5,1000,0,"sample1.wav",100

[TimingPoints]
0,500,4,2,0,70,1,0
1000,-200,4,2,0,80,0,0
2000,500,4,2,0,70,1,0
2000,-50,4,2,0,80,0,0


[HitObjects]
320,0,0,128,0,1000:1:0:0:0:
64,192,1000,5,6,0:0:0:0:]]

test_chart = test_chart:gsub("\n", "\r\n")

function test.basic(t)
	local raw_osu = RawOsu()
	local osu = Osu(raw_osu)

	raw_osu:decode(test_chart)
	osu:decode()

	t:eq(#osu.protoTempos, 2)
	t:eq(osu.protoTempos[1].tempo, 120)
	t:eq(osu.protoTempos[2].tempo, 120)

	t:eq(#osu.protoVelocities, 3)
	t:eq(osu.protoVelocities[1].velocity, 1)
	t:eq(osu.protoVelocities[2].velocity, 0.5)
	t:eq(osu.protoVelocities[3].velocity, 2)

	t:eq(#osu.protoNotes, 2)
	t:eq(osu.protoNotes[1].column, 3)
	t:eq(osu.protoNotes[2].column, 1)
end

return test
