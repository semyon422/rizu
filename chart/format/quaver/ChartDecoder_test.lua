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

return test
