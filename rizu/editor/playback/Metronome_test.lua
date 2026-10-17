local FakeFilesystem = require("fs.FakeFilesystem")
local Fraction = require("chart.core.Fraction")
local Metronome = require("rizu.editor.playback.Metronome")

local test = {}

---@param t testing.T
function test.load_reads_sample_through_filesystem(t)
	local fs = FakeFilesystem()
	fs:createDirectory("resources")
	fs:write("resources/metronome.ogg", "sample-data")

	local source = {
		release = function() end,
	}
	local loaded_data
	local metronome = Metronome(fs, function(data)
		loaded_data = data
		return source
	end)
	metronome:load()

	t:eq(loaded_data, "sample-data")
	t:eq(metronome.source, source)
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
	local context = {}
	function context:getPoint()
			return point
	end
	function context:getCurrentTime()
			return 0.5
	end
	function context:getNextSnapIntervalTime()
			error("next snap should not be requested")
	end
	function context:interpolateFraction()
			error("next point should not be interpolated")
	end
	metronome:setContext(context)

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
	local context = {}
	function context:getPoint()
			return point
	end
	function context:getCurrentTime()
			return 0.75
	end
	function context:getNextSnapIntervalTime(loadedPoint, delta)
			t:eq(loadedPoint, point)
			t:eq(delta, 1)
			return vertex, Fraction(3, 2)
	end
	function context:interpolateFraction(loadedVertex, time)
			t:eq(loadedVertex, vertex)
			t:eq(time, Fraction(3, 2))
			return nextPoint
	end
	metronome:setContext(context)

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

---@param t testing.T
function test.update_clamps_persisted_volume_values(t)
	local calls = {}
	local metronome = Metronome(FakeFilesystem())
	metronome.volume = {
		master = 2,
		metronome = -0.25,
	}
	metronome.nextTime = 1
	metronome.isNextBeat = false
	metronome.source = {
		stop = function() end,
		setVolume = function(_, volume)
			table.insert(calls, "volume:" .. volume)
		end,
		setRate = function() end,
		play = function() end,
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

	t:tdeq(calls, {"volume:0"})
end

return test
