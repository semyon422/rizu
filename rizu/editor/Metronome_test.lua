local audio = require("audio")
local FakeFilesystem = require("fs.FakeFilesystem")
local Fraction = require("chart.core.Fraction")
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

---@param t testing.T
function test.update_next_time_uses_current_point_before_current_time(t)
	local point = {
		time = Fraction(1, 1),
		tonumber = function()
			return 1
		end,
	}
	local metronome = Metronome(FakeFilesystem())
	metronome:setContext({
		getPoint = function()
			return point
		end,
		getCurrentTime = function()
			return 0.5
		end,
		getNextSnapIntervalTime = function()
			error("next snap should not be requested")
		end,
		interpolateFraction = function()
			error("next point should not be interpolated")
		end,
	})

	metronome:updateNextTime()

	t:eq(metronome.nextTime, 1)
	t:eq(metronome.isNextBeat, true)
end

---@param t testing.T
function test.update_next_time_uses_next_snap_after_current_point(t)
	local point = {
		time = Fraction(1, 2),
		tonumber = function()
			return 0.5
		end,
	}
	local vertex = {}
	local nextPoint = {
		time = Fraction(3, 2),
		tonumber = function()
			return 1.5
		end,
	}
	local metronome = Metronome(FakeFilesystem())
	metronome:setContext({
		getPoint = function()
			return point
		end,
		getCurrentTime = function()
			return 0.75
		end,
		getNextSnapIntervalTime = function(loadedPoint, delta)
			t:eq(loadedPoint, point)
			t:eq(delta, 1)
			return vertex, Fraction(3, 2)
		end,
		interpolateFraction = function(loadedVertex, time)
			t:eq(loadedVertex, vertex)
			t:eq(time, Fraction(3, 2))
			return nextPoint
		end,
	})

	metronome:updateNextTime()

	t:eq(metronome.nextTime, 1.5)
	t:eq(metronome.isNextBeat, false)
end

---@param t testing.T
function test.update_plays_click_when_next_time_reached(t)
	local calls = {}
	local metronome = Metronome(FakeFilesystem())
	metronome.volume = {
		master = 0.5,
		metronome = 0.25,
	}
	metronome.nextTime = 1
	metronome.isNextBeat = true
	metronome.source = {
		stop = function()
			table.insert(calls, "stop")
		end,
		setVolume = function(_, volume)
			table.insert(calls, "volume:" .. volume)
		end,
		setRate = function(_, rate)
			table.insert(calls, "rate:" .. rate)
		end,
		play = function()
			table.insert(calls, "play")
		end,
	}
	local point = {
		time = Fraction(1, 1),
		tonumber = function()
			return 2
		end,
	}
	metronome:setContext({
		getPoint = function()
			return point
		end,
		getCurrentTime = function()
			return 1
		end,
		getNextSnapIntervalTime = function()
			error("next snap should not be requested")
		end,
		interpolateFraction = function()
			error("next point should not be interpolated")
		end,
	})

	metronome:update()

	t:tdeq(calls, {
		"stop",
		"volume:0.125",
		"rate:" .. (2099 / 2645),
		"rate:1",
		"play",
	})
	t:eq(metronome.nextTime, 2)
end

return test
