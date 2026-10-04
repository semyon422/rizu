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
	t:eq(engine.mixer:getSampleFormat(), "float32")
	t:eq(engine.source.decoder:getSampleFormat(), "float32")
	t:eq(engine:getStartTime(), 1)

	engine:play()
	t:assert(engine.source:isPlaying())

	engine:update()
	t:assert(engine.source:getPosition() > 0)

	engine:playSample("bg", 0.5)
	t:eq(#engine.foregroundSource.active_sounds, 1)
	t:eq(engine.foregroundSource.sample_format, "float32")
	t:eq(engine.foregroundSource.active_sounds[1].decoder:getSampleFormat(), "float32")
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
		getFrameDuration = function()
			return 4
		end,
		getSampleFormat = function()
			return "float32"
		end,
		---@param self {position: number}
		---@param byte_ptr ffi.cdata*
		---@param len integer
		---@return integer
		getFrames = function(self, byte_ptr, frame_count)
			t:eq(self.position, 1)
			t:eq(frame_count, 4)
			---@type {[integer]: number}
			local samples = ffi.cast("float*", byte_ptr)
			for i = 0, 3 do
				samples[i] = (100 + i) / 32768
			end
			return frame_count
		end,
	}

	local wave = engine:renderWave()

	t:tdeq(positions, {1, 3})
	t:eq(engine.mixer.position, 3)
	t:eq(wave.samples_count, 4)
	t:eq(wave:getSampleInt(0, 1), 100)
	t:eq(wave:getSampleInt(3, 1), 103)
end

---@param t testing.T
function test.render_wave_returns_empty_wave_for_empty_mixer(t)
	local engine = AudioEngine()
	engine.mixer = {
		empty = true,
	}

	local wave = engine:renderWave()

	t:eq(wave.samples_count, 0)
	t:eq(wave.channels_count, 0)
end

---@param t testing.T
function test.audio_offset_compensates_engine_clock_and_runtime_changes(t)
	local engine = AudioEngine()
	engine.offset = 0
	engine.source = {
		position = 2,
		getPosition = function(self) return self.position end,
		setPosition = function(self, position) self.position = position end,
		setRate = function(self, rate) self.rate = rate end,
	}
	engine.output = {
		getPosition = function(_, position) return position end,
		clear = function() end,
		update = function() end,
	}
	engine.chart_audio = {getStartTime = function() return 1 end}
	t:eq(engine:getPosition(), 2)
	engine:setOffset(0.25)
	t:eq(engine.source:getPosition(), 2.25)
	t:eq(engine:getPosition(), 2)
	t:eq(engine:getStartTime(), 0.75)
	engine:setOffset(-0.5)
	t:eq(engine.source:getPosition(), 1.5)
	t:eq(engine:getPosition(), 2)
	engine:setRate(1.5)
	engine:setPosition(2.1)
	t:aeq(engine.source:getPosition(), 1.6, 1e-9)
	t:aeq(engine:getPosition(), 2.1, 1e-9)
	engine:setOffset(0)
	t:aeq(engine:getPosition(), 2.1, 1e-9)
end

---@param t testing.T
function test.audio_offset_preserves_clock_with_latency_and_repeated_changes(t)
	for _, rate in ipairs({0.5, 1, 1.5, 2}) do
		local engine = AudioEngine()
		local seeks = 0
		local source = {
			position = 2.04,
			getPosition = function(self) return self.position end,
			setPosition = function(self, position)
				self.position = position
				seeks = seeks + 1
			end,
			setRate = function(self, value) self.rate = value end,
		}
		engine.source = source
		engine.output = {
			getPosition = function(_, position) return position - 0.04 end,
			clear = function() error("offset changes must preserve queued output") end,
			update = function() error("offset changes must not refill queued output") end,
		}
		engine:setRate(rate)
		t:aeq(engine:getPosition(), 2, 1e-9)
		engine:setOffset(0.25)
		t:aeq(engine.source:getPosition(), 2.29, 1e-9)
		t:aeq(engine:getPosition(), 2, 1e-9)
		engine:setOffset(0.25)
		t:eq(seeks, 1)
		t:aeq(engine:getPosition(), 2, 1e-9)
		engine:setOffset(-0.5)
		t:aeq(engine.source:getPosition(), 1.54, 1e-9)
		t:aeq(engine:getPosition(), 2, 1e-9)
		source.position = source.position + 0.1 * rate
		t:aeq(engine:getPosition(), 2 + 0.1 * rate, 1e-9)
		engine:setOffset(0)
		t:aeq(engine:getPosition(), 2 + 0.1 * rate, 1e-9)
		t:eq(seeks, 3)
	end
end

---@param t testing.T
function test.audio_offset_reapplies_after_source_reload(t)
	local engine = AudioEngine()
	engine:setEnabled(false)
	local chart = {
		notes = {
			iter = function()
				return ipairs({{
					type = "tap",
					visualPoint = {point = {absoluteTime = 1}},
					data = {sounds = {{"bg", 1}}},
				}})
			end,
		},
	}
	local resources = {bg = 100}
	engine:load(chart, resources, true)
	engine:setPosition(2)
	engine:setOffset(0.25)
	t:aeq(engine.source:getPosition(), 2.25, 1e-9)
	engine:unload()
	t:eq(engine.offset, 0)
	engine:load(chart, resources, true)
	engine:setPosition(2)
	engine:setOffset(0.25)
	t:aeq(engine.source:getPosition(), 2.25, 1e-9)
	t:aeq(engine:getPosition(), 2, 1e-9)
	engine:unload()
end

return test
