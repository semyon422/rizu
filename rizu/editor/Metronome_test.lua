local audio = require("audio")
local FakeFilesystem = require("fs.FakeFilesystem")
local Metronome = require("rizu.editor.Metronome")

local test = {}

---@param t testing.T
function test.load_reads_sample_through_filesystem(t)
	local fs = FakeFilesystem()
	fs:createDirectory("resources")
	fs:write("resources/metronome.ogg", "sample-data")

	local oldSoundData = audio.SoundData
	local oldNewSource = audio.newSource
	local soundData = {
		release = function() end,
	}
	local source = {
		release = function() end,
	}
	local calls = {}
	audio.SoundData = function(_, size)
		table.insert(calls, "sound:" .. size)
		return soundData
	end
	audio.newSource = function(loadedSoundData)
		table.insert(calls, "source")
		t:eq(loadedSoundData, soundData)
		return source
	end

	local metronome = Metronome(fs)
	metronome:load()
	audio.SoundData = oldSoundData
	audio.newSource = oldNewSource

	t:eq(metronome.soundData, soundData)
	t:eq(metronome.source, source)
	t:tdeq(calls, {"sound:11", "source"})
end

return test
