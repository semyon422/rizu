local ChartDecoder = require("chart.format.quaver.ChartDecoder")

local test = {}

local test_chart = [[
AudioFile: audio.mp3
SongPreviewTime: 1
BackgroundFile: bg.jpg
Mode: Keys4
Title: Title
Artist: Artist
Source: Source
Tags: Tags
Creator: Creator
DifficultyName: DifficultyName
BPMDoesNotAffectScrollVelocity: true
InitialScrollVelocity: 1
CustomAudioSamples: []
SoundEffects: []
TimingPoints:
- Bpm: 200
- StartTime: 500
  Bpm: 200
SliderVelocities:
- Multiplier: 0.5
- StartTime: 50
- StartTime: 100
  Multiplier: 100
HitObjects:
- StartTime: 50
  Lane: 1
  KeySounds: []
  EditorLayer: 1
- StartTime: 200
  Lane: 4
  HitSound: Normal, Clap
  KeySounds: []
  EditorLayer: 2
]]

function test.basic(t)
	local dec = ChartDecoder()
	dec:decode(test_chart)
end

function test.hold_end_and_tap_at_same_time(t)
	local s = test_chart:gsub("HitObjects:.*", [[
HitObjects:
- StartTime: 100
  Lane: 3
  EndTime: 200
  KeySounds: []
- StartTime: 200
  Lane: 3
  KeySounds: []
]])
	local res = ChartDecoder():decode(s)
	local count = 0
	for _, note in ipairs(res[1].chart.notes:getLinkedNotes()) do
		if note:getColumn() == "key3" then
			count = count + 1
		end
	end
	t:eq(count, 2)
end

return test
