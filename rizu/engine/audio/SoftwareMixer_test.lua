local SoftwareMixer = require("rizu.engine.audio.SoftwareMixer")
local FakeDecoder = require("rizu.engine.audio.fake.Decoder")
local ffi = require("ffi")

local test = {}

---@param wave audio.Wave
---@param offset integer?
---@param mul integer?
local function fill_wave(wave, offset, mul)
	offset = offset or 0
	mul = mul or 1
	for i = 0, wave.samples_count - 1 do
		for c = 1, wave.channels_count do
			wave:setSampleInt(i, c, offset + i * mul)
		end
	end
end

---@param t testing.T
function test.empty(t)
	local mixer = SoftwareMixer({}, {})

	local buf_size = 20
	local buf = ffi.new("int16_t[?]", buf_size)

	t:eq(mixer:getData(buf, 3), 0)
	t:eq(mixer:getData(buf, 4), 4)
end

---@param t testing.T
function test.single(t)
	---@type rizu.ChartAudioSound[]
	local sounds = {
		{time = 0, name = "a"},
	}

	local decoders = {
		FakeDecoder(4),
	}
	fill_wave(decoders[1].wave, 10)

	local mixer = SoftwareMixer(sounds, decoders)

	local buf_size = 20
	local buf = ffi.new("int16_t[?]", buf_size)
	local function clean()
		ffi.fill(buf, buf_size * 2, 0)
	end

	t:eq(mixer:getData(buf, 3), 0)
	t:eq(buf[0], 0)
	t:eq(buf[1], 0)
	clean()

	t:eq(mixer:getData(buf, 4), 4)
	t:eq(buf[0], 10)
	t:eq(buf[1], 10)
	clean()

	t:eq(mixer:getData(buf, 5), 4)
	t:eq(buf[0], 11)
	t:eq(buf[1], 11)
	clean()

	local result = {
		[0] = 10, 11, 12, 13,
	}

	mixer:setPosition(0)
	t:eq(mixer:getData(buf, buf_size * 2), 40)
	for i = 0, 9 do
		t:eq(buf[i * 2], result[i] or 0)
	end
end

---@param t testing.T
function test.multiple(t)
	---@type rizu.ChartAudioSound[]
	local sounds = {
		{time = 0, name = "a"},
		{time = 2, name = "b"},
	}

	local decoders = {
		FakeDecoder(4, 1),
		FakeDecoder(4, 1),
	}
	fill_wave(decoders[1].wave, 10)
	fill_wave(decoders[2].wave, 100)

	local mixer = SoftwareMixer(sounds, decoders)

	local buf_size = 20
	local buf = ffi.new("int16_t[?]", buf_size)
	local function clean()
		ffi.fill(buf, buf_size * 2, 0)
	end
	local function as_table(n)
		local t = {}
		for i = 0, n - 1 do
			table.insert(t, buf[i * 2])
		end
		return t
	end

	local result = {
		[0] = 10, 11, 112, 114, 102, 103, 0
	}

	local function test_by_frames(time)
		mixer:setPosition(time)

		for i = time, #result do
			local v = result[i] or 0
			t:eq(mixer:getPosition(), i)
			t:eq(mixer:getData(buf, 4), 4)
			t:eq(mixer:getPosition(), i + 1)
			t:eq(buf[0], v)
			clean()
		end
	end

	for i = -2, 8 do
		test_by_frames(i)
	end

	mixer:setPosition(0)
	t:eq(mixer:getData(buf, buf_size * 2), 40)
	t:eq(mixer:getPosition(), 10)
	t:tdeq(as_table(7), {10, 11, 112, 114, 102, 103, 0})
	clean()

	mixer:setPosition(3)
	t:eq(mixer:getData(buf, buf_size * 2), 40)
	t:eq(mixer:getPosition(), 13)
	t:tdeq(as_table(4), {114, 102, 103, 0})
	clean()

	mixer:setPosition(-1)
	t:eq(mixer:getData(buf, buf_size * 2), 40)
	t:eq(mixer:getPosition(), 9)
	t:tdeq(as_table(7), {0, 10, 11, 112, 114, 102, 103})
	clean()

	--

	mixer:setPosition(-1)
	t:eq(mixer:getData(buf, 8), 8)
	t:eq(mixer:getPosition(), 1)
	t:tdeq(as_table(4), {0, 10, 0, 0})
	clean()

	t:eq(mixer:getData(buf, 8), 8)
	t:eq(mixer:getPosition(), 3)
	t:tdeq(as_table(4), {11, 112, 0, 0})
	clean()
end

---@param t testing.T
function test.complex(t)
	local sounds = {
		{time = 0},
		{time = 0},
		{time = 1},
	}
	local decoders = {
		FakeDecoder(4, 1),
		FakeDecoder(4, 1),
		FakeDecoder(4, 1),
	}

	-- Sample 0: Positive clipping (20000 + 20000 = 40000 -> 32767)
	decoders[1].wave:setSampleInt(0, 1, 20000)
	decoders[1].wave:setSampleInt(0, 2, 20000)
	decoders[2].wave:setSampleInt(0, 1, 20000)
	decoders[2].wave:setSampleInt(0, 2, 20000)

	-- Sample 1: Negative clipping (-20000 + -20000 = -40000 -> -32768)
	decoders[1].wave:setSampleInt(1, 1, -20000)
	decoders[1].wave:setSampleInt(1, 2, -20000)
	decoders[2].wave:setSampleInt(1, 1, -20000)
	decoders[2].wave:setSampleInt(1, 2, -20000)

	-- Sample 2: 3-way overlap at time 2 (but we can test it at any point after time 1)
	-- Since time=1 is Sample 1 (if sample_rate=1), let's use Sample 2.
	-- sounds[3].time = 1 means it starts at Sample 1.
	-- So at Sample 2, all 3 are active.
	decoders[1].wave:setSampleInt(2, 1, 10)
	decoders[1].wave:setSampleInt(2, 2, 10)
	decoders[2].wave:setSampleInt(2, 1, 20)
	decoders[2].wave:setSampleInt(2, 2, 20)
	decoders[3].wave:setSampleInt(1, 1, 30)
	decoders[3].wave:setSampleInt(1, 2, 30)

	local mixer = SoftwareMixer(sounds, decoders)
	local buf = ffi.new("int16_t[10]")

	-- 1. Test Positive Clipping
	t:eq(mixer:getData(buf, 4), 4) -- Sample 0
	t:eq(buf[0], 32767)
	t:eq(buf[1], 32767)

	-- 2. Test Negative Clipping
	t:eq(mixer:getData(buf, 4), 4) -- Sample 1
	t:eq(buf[0], -32768)
	t:eq(buf[1], -32768)

	-- 3. Test 3-way Overlap
	t:eq(mixer:getData(buf, 4), 4) -- Sample 2
	t:eq(buf[0], 60)
	t:eq(buf[1], 60)
end

---@param t testing.T
function test.no_intermediate_clipping(t)
	local sounds = {
		{time = 0},
		{time = 0},
		{time = 0},
	}
	local decoders = {
		FakeDecoder(1, 1),
		FakeDecoder(1, 1),
		FakeDecoder(1, 1),
	}

	-- 20000 + 20000 - 20000 should be 20000.
	-- If it clipped at each step: (20000 + 20000) -> 32767, 32767 - 20000 = 12767.
	decoders[1].wave:setSampleInt(0, 1, 20000)
	decoders[1].wave:setSampleInt(0, 2, 20000)
	decoders[2].wave:setSampleInt(0, 1, 20000)
	decoders[2].wave:setSampleInt(0, 2, 20000)
	decoders[3].wave:setSampleInt(0, 1, -20000)
	decoders[3].wave:setSampleInt(0, 2, -20000)

	local mixer = SoftwareMixer(sounds, decoders)
	local buf = ffi.new("int16_t[4]")

	t:eq(mixer:getData(buf, 4), 4)
	t:eq(buf[0], 20000)
	t:eq(buf[1], 20000)
end

---@param t testing.T
function test.dynamic(t)
	local mixer = SoftwareMixer({}, {})
	t:assert(mixer.empty)

	local decoder = FakeDecoder(4, 1, 1)
	fill_wave(decoder.wave, 10)

	mixer:addSound({time = 1}, decoder)
	t:assert(not mixer.empty)
	t:eq(mixer:getSamplesDuration(), 4)
	t:eq(mixer:getPosition(), 0)

	local buf = ffi.new("int16_t[10]")
	local function clean()
		ffi.fill(buf, 20, 0)
	end

	-- Time 0: no sound (starts at 1)
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 0)
	clean()

	-- Time 1: sound starts
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 10)
	clean()

	-- Dynamic removal
	mixer:removeSound(decoder)
	t:assert(mixer.empty)

	mixer:setPosition(1)
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 0)
end

---@param t testing.T
function test.seeking(t)
	local sounds = {
		{time = 1},
		{time = 5},
	}
	local decoders = {
		FakeDecoder(2, 1, 1), -- duration 2, ends at 3
		FakeDecoder(2, 1, 1), -- duration 2, ends at 7
	}
	fill_wave(decoders[1].wave, 10)
	fill_wave(decoders[2].wave, 100)

	local mixer = SoftwareMixer(sounds, decoders)
	local buf = ffi.new("int16_t[2]")

	-- Seek to 0 (before everything)
	mixer:setPosition(0)
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 0)

	-- Seek to 1 (start of first sound)
	mixer:setPosition(1)
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 10)

	-- Seek to 2 (middle of first sound)
	mixer:setPosition(2)
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 11)

	-- Seek to 4 (between sounds)
	mixer:setPosition(4)
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 0)

	-- Seek to 5 (start of second sound)
	mixer:setPosition(5)
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 100)

	-- Seek to 6 (middle of second sound)
	mixer:setPosition(6)
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 101)

	-- Seek to 8 (after everything)
	mixer:setPosition(8)
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 0)

	-- Seek backwards from 8 to 2
	mixer:setPosition(2)
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 11)
end

---@param t testing.T
function test.dynamic_playback(t)
	-- Use a sound to initialize format to 1Hz, 1ch
	local init_dec = FakeDecoder(1, 1, 1)
	local mixer = SoftwareMixer({{time = -100}}, {init_dec})
	mixer:setPosition(0)

	local buf = ffi.new("int16_t[2]")

	local dec1 = FakeDecoder(2, 1, 1)
	fill_wave(dec1.wave, 10)

	-- Start playing empty (except the far away init sound)
	t:eq(mixer:getData(buf, 2), 2) -- pos 0 -> 1
	t:eq(buf[0], 0)

	-- Add sound that starts at 0 while we are at 1
	mixer:addSound({time = 0}, dec1)
	t:eq(mixer:getPosition(), 1)
	t:eq(mixer:getData(buf, 2), 2) -- pos 1 -> 2
	t:eq(buf[0], 11) -- second sample of dec1

	-- Add another sound that starts at 3
	local dec2 = FakeDecoder(2, 1, 1)
	fill_wave(dec2.wave, 100)
	mixer:addSound({time = 3}, dec2)

	t:eq(mixer:getData(buf, 2), 2) -- pos 2 -> 3
	t:eq(buf[0], 0) -- gap

	t:eq(mixer:getData(buf, 2), 2) -- pos 3 -> 4
	t:eq(buf[0], 100) -- first sample of dec2

	-- Remove dec2 while playing it
	mixer:removeSound(dec2)
	t:eq(mixer:getData(buf, 2), 2) -- pos 4 -> 5
	t:eq(buf[0], 0)
end

---@param t testing.T
function test.overlap_seeking(t)
	local sounds = {
		{time = 0},
		{time = 1},
	}
	local decoders = {
		FakeDecoder(3, 1, 1), -- 0 to 3
		FakeDecoder(3, 1, 1), -- 1 to 4
	}
	fill_wave(decoders[1].wave, 10) -- 10, 11, 12
	fill_wave(decoders[2].wave, 100) -- 100, 101, 102

	local mixer = SoftwareMixer(sounds, decoders)
	local buf = ffi.new("int16_t[2]")

	-- pos 0: 10
	mixer:setPosition(0)
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 10)

	-- pos 1: 11 + 100 = 111
	mixer:setPosition(1)
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 111)

	-- pos 2: 12 + 101 = 113
	mixer:setPosition(2)
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 113)

	-- pos 3: 102
	mixer:setPosition(3)
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 102)

	-- pos 4: 0
	mixer:setPosition(4)
	t:eq(mixer:getData(buf, 2), 2)
	t:eq(buf[0], 0)
end

---@param t testing.T
function test.many_sounds(t)
	local n = 100
	local sounds = {}
	local decoders = {}
	for i = 1, n do
		table.insert(sounds, {time = i})
		local dec = FakeDecoder(1, 1, 1)
		dec.wave:setSampleInt(0, 1, i)
		table.insert(decoders, dec)
	end

	local mixer = SoftwareMixer(sounds, decoders)
	local buf = ffi.new("int16_t[2]")

	for i = 1, n do
		mixer:setPosition(i)
		t:eq(mixer:getData(buf, 2), 2)
		t:eq(buf[0], i)
	end
end

---@param t testing.T
function test.simultaneous(t)
	local n = 5
	local sounds = {}
	local decoders = {}
	for i = 1, n do
		table.insert(sounds, {time = 0})
		local dec = FakeDecoder(1, 1, 1)
		dec.wave:setSampleInt(0, 1, 10 ^ (i - 1))
		table.insert(decoders, dec)
	end

	local mixer = SoftwareMixer(sounds, decoders)
	local buf = ffi.new("int16_t[2]")

	t:eq(mixer:getData(buf, 2), 2)
	-- Sum: 1 + 10 + 100 + 1000 + 10000 = 11111
	t:eq(buf[0], 11111)

	-- Remove middle sound (100)
	mixer:removeSound(decoders[3])
	mixer:setPosition(0)
	t:eq(mixer:getData(buf, 2), 2)
	-- Sum: 1 + 10 + 1000 + 10000 = 11011
	t:eq(buf[0], 11011)
end

---@param t testing.T
function test.id_consistency(t)
	local mixer = SoftwareMixer({}, {})
	local dec1 = FakeDecoder(1, 1, 1)
	local dec2 = FakeDecoder(1, 1, 1)

	mixer:addSound({time = 0}, dec1)
	mixer:addSound({time = 0}, dec2)

	local entry1 = mixer.decoder_to_entry[dec1]
	local entry2 = mixer.decoder_to_entry[dec2]

	t:assert(entry1.id ~= entry2.id, "Entries should have unique IDs")

	-- Ensure they are in the trees
	t:assert(mixer.tree_start.size == 2)
	t:assert(mixer.tree_end.size == 2)

	-- Remove and re-add to check if ID logic still works
	mixer:removeSound(dec1)
	t:assert(mixer.tree_start.size == 1)
	mixer:addSound({time = 0}, dec1)
	t:assert(mixer.tree_start.size == 2)

	local entry1_new = mixer.decoder_to_entry[dec1]
	t:assert(entry1_new.id > entry2.id, "New entry should have a larger ID")
end

---@param t testing.T
function test.negative_start(t)
	-- 1Hz, 1ch for simplicity
	local sample_rate = 1
	local channels = 1

	-- Sound at time -5, duration 10 (ends at 5)
	local sounds = {{time = -5}}
	local decoders = {FakeDecoder(10, sample_rate, channels)}
	-- Fill decoder with data 1, 2, 3, ...
	for i = 0, 9 do
		decoders[1].wave:setSampleInt(i, 1, i + 1)
	end

	local mixer = SoftwareMixer(sounds, decoders)
	t:eq(mixer:getPosition(), -5, "Mixer should start at start_pos (-5)")
	t:eq(mixer:getDuration(), 10, "Duration should be end_pos - start_pos (10s)")

	local buf = ffi.new("int16_t[20]")
	local read = mixer:getData(buf, 20)
	t:eq(read, 20, "Should read all 10 samples (20 bytes)")
	t:eq(mixer:getPosition(), 5, "Mixer should reach 5s after reading 10s from -5s")

	for i = 0, 9 do
		t:eq(buf[i], i + 1, "Sample " .. i .. " should be correct")
	end
end

---@param t testing.T
function test.float_output(t)
	---@type rizu.ChartAudioSound[]
	local sounds = {
		{time = 0, name = "a"},
	}

	local decoders = {
		FakeDecoder(4),
	}
	fill_wave(decoders[1].wave, 10)

	local mixer = SoftwareMixer(sounds, decoders, "float32")
	local buf = ffi.new("float[?]", 20)

	t:eq(mixer:getBytesPerSample(), 4)
	t:eq(mixer:getBytesDuration(), 32)
	t:eq(mixer:getData(buf, 8), 8)
	t:aeq(buf[0], 10 / 32768, 0.000001)
	t:aeq(buf[1], 10 / 32768, 0.000001)
	t:eq(mixer:getBytesPosition(), 8)
	t:aeq(mixer:getPosition(), 1 / 44100, 1e-9)

	mixer:setBytesPosition(16)
	t:eq(mixer:getBytesPosition(), 16)
	t:eq(mixer:getData(buf, 8), 8)
	t:aeq(buf[0], 12 / 32768, 0.000001)
end

return test
