local ChartEncoder = require("chart.format.osu.ChartEncoder")
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

local out_chart = [[
osu file format v14

[General]
AudioFilename: virtual
AudioLeadIn: 0
PreviewTime: 0
Countdown: 0
SampleSet: 0
StackLeniency: 0
Mode: 3
LetterboxInBreaks: 0

[Editor]
DistanceSpacing: 1
BeatDivisor: 4
GridSize: 4
TimelineZoom: 1

[Metadata]
Title:
TitleUnicode:
Artist:
ArtistUnicode:
Creator:
Version:
Source:
Tags:
BeatmapID:0
BeatmapSetID:-1

[Difficulty]
HPDrainRate:5
CircleSize:4
OverallDifficulty:5
ApproachRate:5
SliderMultiplier:1.4
SliderTickRate:1

[Events]
//Background and Video events
//Break Periods
//Storyboard Layer 0 (Background)
//Storyboard Layer 1 (Fail)
//Storyboard Layer 2 (Pass)
//Storyboard Layer 3 (Foreground)
//Storyboard Layer 4 (Overlay)
//Storyboard Sound Samples
5,1000,0,"sample1.wav",1

[TimingPoints]
0,500,4,0,0,0,1,0
0,-100,4,0,0,0,0,0
1000,-200,4,0,0,0,0,0


[HitObjects]
320,192,0,128,1,1000:0:0:0:56:normal-hitnormal
64,192,1000,1,1,0:0:0:80:soft-hitfinish]]

out_chart = out_chart:gsub("\n", "\r\n")

function test.basic(t)
	local dec = ChartDecoder()
	local chart_chartmetas = dec:decode(test_chart)

	local enc = ChartEncoder()
	local s = enc:encode(chart_chartmetas)
	t:eq(s, out_chart)

	-- TODO: fix this test
end

return test
