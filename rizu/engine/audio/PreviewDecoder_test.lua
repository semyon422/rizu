local PreviewDecoder = require("rizu.engine.audio.PreviewDecoder")
local FakeFilesystem = require("fs.FakeFilesystem")
local AudioPreview = require("rizu.preview.AudioPreview")
local FakeDecoder = require("rizu.engine.audio.fake.Decoder")
local Fixtures = require("chart.format.iidx.TestFixtures")
local ffi = require("ffi")

local test = {}

local asf_header = string.char(
	0x30, 0x26, 0xb2, 0x75, 0x8e, 0x66, 0xcf, 0x11,
	0xa6, 0xd9, 0x00, 0xaa, 0x00, 0x62, 0xce, 0x6c
)

---@param t testing.T
function test.on_demand_loading(t)
	local fs = FakeFilesystem()
	fs:write("kick.wav", "kick_data")
	fs:write("snare.wav", "snare_data")

	local preview = AudioPreview()
	preview.samples = {"kick.wav", "snare.wav"}
	preview.events = {
		{time = 0.5, sample_index = 1, duration = 0.1, volume = 1},
		{time = 1.5, sample_index = 2, duration = 0.1, volume = 1},
	}

	---@type {[string]: integer}
	local loaded = {}
	local function factory(data)
		loaded[data] = (loaded[data] or 0) + 1
		local sample_rate = 44100
		local duration = 0.1
		return FakeDecoder(math.floor(duration * sample_rate), sample_rate, 2)
	end

	local decoder = PreviewDecoder(fs, "", preview, factory)

	-- Construction probes the first sound to get format
	t:eq(loaded["kick_data"], 1, "Should have probed kick.wav")
	t:eq(loaded["snare_data"], nil, "Should NOT have loaded snare.wav yet")

	-- Seek to 1.0 (after kick, before snare)
	decoder:setPosition(1.0)

	t:eq(loaded["kick_data"], 1, "Kick should still only be probed once")
	t:eq(loaded["snare_data"], nil, "Snare should still not be loaded")

	-- Read data where snare is active (1.5)
	local buf_len = 44100 * 2 * 2 * 1 -- 1 second
	local buf = ffi.new("int16_t[?]", buf_len / 2)

	decoder:getData(buf, buf_len) -- reads 1.0 to 2.0

	t:eq(loaded["snare_data"], 1, "Snare should have been loaded on-demand during getData")

	decoder:release()
end

---@param t testing.T
function test.volume_application(t)
	local fs = FakeFilesystem()
	fs:write("tone.wav", "tone_data")

	local preview = AudioPreview()
	preview.samples = {"tone.wav"}
	preview.events = {
		{time = 0, sample_index = 1, duration = 1.0, volume = 0.5},
	}

	local function factory(data)
		local sample_rate = 44100
		local duration = 1.0
		return FakeDecoder(math.floor(duration * sample_rate), sample_rate, 2)
	end

	local decoder = PreviewDecoder(fs, "", preview, factory)

	local buf_len = 44100 * 2 * 2
	local buf = ffi.new("int16_t[?]", buf_len / 2)

	decoder:getData(buf, buf_len)

	-- Let's compare with a full volume one.
	local preview_full = AudioPreview()
	preview_full.samples = {"tone.wav"}
	preview_full.events = {
		{time = 0, sample_index = 1, duration = 1.0, volume = 1.0},
	}
	local decoder_full = PreviewDecoder(fs, "", preview_full, factory)
	local buf_full = ffi.new("int16_t[?]", buf_len / 2)
	decoder_full:getData(buf_full, buf_len)

	-- Verify volume 0.5
	for i = 0, 100 do
		t:eq(buf[i], math.floor(buf_full[i] * 0.5 + 0.5), "Sample " .. i .. " should have half volume")
	end

	decoder:release()
	decoder_full:release()
end

---@param t testing.T
function test.resource_finder_integration(t)
	local fs = FakeFilesystem()
	fs:createDirectory("my_chart")
	fs:createDirectory("my_chart/audio")
	fs:write("my_chart/audio/bgm.ogg", "bgm_data")

	local preview = AudioPreview()
	preview.samples = {"audio/bgm"}
	preview.events = {
		{time = 0, sample_index = 1, duration = 10, volume = 1},
	}

	local found_data = nil
	local function factory(data)
		found_data = data
		local sample_rate = 44100
		local duration = 10
		return FakeDecoder(math.floor(duration * sample_rate), sample_rate, 2)
	end

	local decoder = PreviewDecoder(fs, "my_chart", preview, factory)
	t:eq(found_data, "bgm_data", "Should have loaded bgm_data")

	decoder:release()
end

---@param t testing.T
function test.s3p_inside_ifs(t)
	local fs = FakeFilesystem()
	fs:createDirectory("chart")
	fs:write("chart/01234.ifs", Fixtures.ifs(1234, Fixtures.sampleChart(), Fixtures.s3p({"sound1", "sound2"})))

	local preview = AudioPreview()
	preview.samples = {"01234/01234.s3p"}
	preview.events = {
		{time = 0, sample_index = 1, duration = 0.1, volume = 1},
		{time = 1, sample_index = 2, duration = 0.1, volume = 1},
	}

	---@type {[string]: integer}
	local loaded = {}
	local function factory(data)
		loaded[data] = (loaded[data] or 0) + 1
		local sample_rate = 44100
		local duration = 0.1
		return FakeDecoder(math.floor(duration * sample_rate), sample_rate, 2)
	end

	local decoder = PreviewDecoder(fs, "chart/01234.ifs", preview, factory)

	t:eq(loaded.sound1, nil)
	t:eq(loaded.sound2, nil)

	local buf_len = 44100 * 2 * 2
	local buf = ffi.new("int16_t[?]", buf_len / 2)
	decoder:getData(buf, buf_len)

	t:eq(loaded.sound1, 1)
	t:eq(loaded.sound2, nil)

	decoder:release()
end

---@param t testing.T
function test.s3p_payload_load_is_on_demand(t)
	local fs = FakeFilesystem()
	fs:createDirectory("chart")
	fs:write("chart/01234.ifs", Fixtures.ifs(1234, Fixtures.sampleChart(), Fixtures.s3p({"RIFFsound1"})))

	local preview = AudioPreview()
	preview.samples = {"01234/01234.s3p"}
	preview.events = {
		{time = 0, sample_index = 1, duration = 0.1, volume = 1},
	}

	---@type {[string]: integer}
	local loaded = {}
	local decoder = PreviewDecoder(fs, "chart/01234.ifs", preview, function(data)
		loaded[data] = (loaded[data] or 0) + 1
		local sample_rate = 44100
		local duration = 0.1
		return FakeDecoder(math.floor(duration * sample_rate), sample_rate, 2)
	end)

	t:eq(loaded.RIFFsound1, nil)

	local buf_len = 44100 * 2 * 2
	local buf = ffi.new("int16_t[?]", buf_len / 2)
	decoder:getData(buf, buf_len)

	t:eq(loaded.RIFFsound1, 1)

	decoder:release()
end

---@param t testing.T
function test.two_dx_inside_ifs(t)
	local fs = FakeFilesystem()
	fs:createDirectory("chart")
	fs:write("chart/01234.ifs", Fixtures.ifs(1234, Fixtures.sampleChart(), nil, {
		{path = "01234/012341.2dx", data = Fixtures.twoDx("012341", {"sound1", "sound2"}), time = 1234},
	}))

	local preview = AudioPreview()
	preview.samples = {"01234/012341.2dx"}
	preview.events = {
		{time = 0, sample_index = 1, duration = 0.1, volume = 1},
		{time = 1, sample_index = 2, duration = 0.1, volume = 1},
	}

	---@type {[string]: integer}
	local loaded = {}
	local function factory(data)
		loaded[data] = (loaded[data] or 0) + 1
		local sample_rate = 44100
		local duration = 0.1
		return FakeDecoder(math.floor(duration * sample_rate), sample_rate, 2)
	end

	local decoder = PreviewDecoder(fs, "chart/01234.ifs", preview, factory)

	t:eq(loaded.sound1, 1)
	t:eq(loaded.sound2, nil)

	decoder:release()
end

---@return fun(data: string): rizu.audio.IDecoder
local function constant_tone_factory()
	return function(_data)
		local dec = FakeDecoder(44100, 44100, 2)
		for i = 0, 44099 do
			dec.wave:setSampleInt(i, 1, 1000)
			dec.wave:setSampleInt(i, 2, 1000)
		end
		return dec
	end
end

---@param output_format rizu.audio.SampleFormat?
---@return rizu.audio.PreviewDecoder
local function tone_preview_decoder(output_format)
	local fs = FakeFilesystem()
	fs:write("tone.wav", "tone_data")

	local preview = AudioPreview()
	preview.samples = {"tone.wav"}
	preview.events = {
		{time = 0, sample_index = 1, duration = 1.0, volume = 0.5},
	}

	return PreviewDecoder(fs, "", preview, constant_tone_factory(), output_format)
end

--- 1.5s buffer: tone occupies frames 0..44099 (88200 interleaved samples),
--- silence starts at sample 88200.
---@param t testing.T
function test.int16_output(t)
	local decoder = tone_preview_decoder()

	t:eq(decoder:getBytesPerSample(), 2, "int16 mode reports 2 bytes per sample")

	local samples = 44100 * 2 * 3
	local buf = ffi.new("int16_t[?]", samples)
	t:eq(decoder:getData(buf, samples * 2), samples * 2, "reads 1.5s of int16 data")

	-- 1000 * 0.5 volume = 500
	t:eq(buf[0], 500, "first L sample")
	t:eq(buf[1], 500, "first R sample")
	t:eq(buf[88198], 500, "last L sample of the tone")
	t:eq(buf[88199], 500, "last R sample of the tone")
	t:eq(buf[88200], 0, "silence after the tone ends")

	decoder:release()
end

---@param t testing.T
function test.float_output(t)
	local decoder = tone_preview_decoder("float32")

	t:eq(decoder:getBytesPerSample(), 4, "float mode reports 4 bytes per sample")

	local samples = 44100 * 2 * 3
	local buf = ffi.new("float[?]", samples)
	t:eq(decoder:getData(buf, samples * 4), samples * 4, "reads 1.5s of float data")

	-- 1000 * 0.5 volume = 500 -> 500/32768 in [-1, 1] range
	t:aeq(buf[0], 500 / 32768, 1e-9, "first L sample")
	t:aeq(buf[1], 500 / 32768, 1e-9, "first R sample")
	t:aeq(buf[88198], 500 / 32768, 1e-9, "last L sample of the tone")
	t:aeq(buf[88199], 500 / 32768, 1e-9, "last R sample of the tone")
	t:aeq(buf[88200], 0, 1e-9, "silence after the tone ends")

	decoder:setPosition(0.5)
	t:aeq(decoder:getPosition(), 0.5, 1e-9, "float byte positions preserve time")
	t:eq(decoder:getData(buf, 8), 8, "reads one stereo float frame after seeking")
	t:aeq(buf[0], 500 / 32768, 1e-9, "seeked L sample")

	decoder:release()
end

return test
