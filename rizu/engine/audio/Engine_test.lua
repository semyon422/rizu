local AudioEngine = require("rizu.engine.audio.Engine")
local ffi = require("ffi")

local test = {}

---@param t testing.T
function test.load_and_play(t)
	local engine = AudioEngine()
	engine:setEnabled(false) -- Ensures FakeAudioProvider is used

	local chart = {
		notes = {
			iter = function()
				return ipairs({
					{
						type = "tap",
						visualPoint = {point = {absoluteTime = 1}},
						data = {sounds = {{"bg", 1}}},
					},
				})
			end,
		},
	}

	local resources = {
		bg = 100, -- 100 samples
	}

	engine:load(chart, resources, true)

	t:assert(engine.source ~= nil)
	t:assert(engine.foregroundSource ~= nil)
	t:eq(engine:getStartTime(), 1)

	engine:play()
	t:assert(engine.source:isPlaying())

	engine:update()
	t:assert(engine.source:getPosition() > 0)

	engine:playSample("bg", 0.5)
	t:eq(#engine.foregroundSource.active_sounds, 1)
	t:eq(engine.foregroundSource.active_sounds[1].volume, 0.5)

	engine:unload()
	t:eq(engine.chart_audio, nil)
end

---@param t testing.T
function test.render_wave_renders_from_start_and_restores_mixer_position(t)
	local engine = AudioEngine()
	local positions = {}
	engine.mixer = {
		position = 3,
		getPosition = function(self)
			return self.position
		end,
		setPosition = function(self, position)
			table.insert(positions, position)
			self.position = position
		end,
		getTimeBounds = function()
			return 1, 5
		end,
		getChannelCount = function()
			return 1
		end,
		getSamplesDuration = function()
			return 4
		end,
		getBytesDuration = function()
			return 8
		end,
		getData = function(self, byte_ptr, len)
			t:eq(self.position, 1)
			t:eq(len, 8)
			local samples = ffi.cast("int16_t*", byte_ptr)
			for i = 0, 3 do
				samples[i] = 100 + i
			end
			return len
		end,
	}

	local wave = engine:renderWave()

	t:tdeq(positions, {1, 3})
	t:eq(engine.mixer.position, 3)
	t:eq(wave.samples_count, 4)
	t:eq(wave:getSampleInt(0, 1), 100)
	t:eq(wave:getSampleInt(3, 1), 103)
end

return test
