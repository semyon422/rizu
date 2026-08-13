local BufferedDecoder = require("rizu.engine.audio.BufferedDecoder")
local FakeDecoder = require("rizu.engine.audio.fake.Decoder")
local YieldingDecoder = require("rizu.engine.audio.fake.YieldingDecoder")
local ffi = require("ffi")

local test = {}

---@param t testing.T
function test.basic_preloading(t)
	local sample_rate = 44100
	local channels = 2
	local bytes_per_sample = 2
	local duration = 10
	local total_samples = duration * sample_rate
	local underlying = FakeDecoder(total_samples, sample_rate, channels)

	-- Fill underlying with some data
	local u_buf_len = total_samples * channels * bytes_per_sample
	local u_buf = ffi.cast("int8_t*", underlying.wave.byte_ptr)
	for i = 0, u_buf_len - 1 do
		u_buf[i] = i % 128
	end

	local buffered = BufferedDecoder(underlying, 0.1) -- 0.1s buffer

	-- Buffer should be filled upon construction or first resume in getData
	local read_len = 1024
	local read_buf = ffi.new("int8_t[?]", read_len)
	local read = buffered:getData(read_buf, read_len)

	t:eq(read, read_len, "Should read full requested length")
	t:eq(buffered:getBytesPosition(), read_len, "Position should advance")

	for i = 0, read_len - 1 do
		t:eq(read_buf[i], i % 128, "Data should match at index " .. i)
	end
end

---@param t testing.T
function test.preload_request_fills_buffer(t)
	local sample_rate = 44100
	local channels = 2
	local bytes_per_sample = 2
	local buffer_seconds = 1
	local requested_len
	local underlying = {
		getSampleRate = function() return sample_rate end,
		getChannelCount = function() return channels end,
		getBytesPerSample = function() return bytes_per_sample end,
		getDuration = function() return 10 end,
		getBytesPosition = function() return 0 end,
		getDataString = function(_, len)
			requested_len = len
			return string.rep("a", len)
		end,
	}
	local buffered = BufferedDecoder(underlying, buffer_seconds)
	local read_buf = ffi.new("int8_t[1024]")

	buffered:getData(read_buf, 1024)

	t:eq(requested_len, sample_rate * channels * bytes_per_sample * buffer_seconds)
end

---@param t testing.T
function test.non_blocking_yield(t)
	local sample_rate = 44100
	local channels = 2
	local bytes_per_sample = 2
	local duration = 10
	local total_samples = duration * sample_rate

	-- Use YieldingDecoder to wrap FakeDecoder
	local underlying = YieldingDecoder(FakeDecoder(total_samples, sample_rate, channels))
	-- Accessing underlying.decoder because FakeDecoder is what actually has the buffer
	local u_buf = ffi.cast("int8_t*", underlying.decoder.wave.byte_ptr)
	ffi.fill(u_buf, 10000, 7)

	-- BufferedDecoder will call getSampleRate, getChannelCount, etc. in new()
	-- YieldingDecoder:new(decoder) is fine, but BufferedDecoder constructor
	-- calls methods that YIELD.
	-- This means BufferedDecoder constructor MUST be called inside a coroutine
	-- if the decoder methods yield.

	---@type rizu.audio.BufferedDecoder
	local buffered
	local co = coroutine.create(function()
		buffered = BufferedDecoder(underlying, 1.0)
	end)

	-- Resume until coroutine is dead
	while coroutine.status(co) ~= "dead" do
		local ok, err = coroutine.resume(co)
		if not ok then error(err) end
	end
	-- Now buffered should be initialized

	local read_len = 1024
	local read_buf = ffi.new("int8_t[?]", read_len)

	-- First getData will resume the preloader.
	-- The preloader will call underlying:getData which will yield.
	-- BufferedDecoder:getData should then return 0 (stall).
	local read = buffered:getData(read_buf, read_len)

	t:eq(read, 0, "Should return 0 (stall)")

	-- Manually resume the preloader since we are in a mock test with no external driver
	coroutine.resume(buffered.preloader_co)

	-- Second getData call will now read from the chunk added by the previous preloader step.
	local read2 = buffered:getData(read_buf, read_len)
	t:eq(read2, read_len, "Should return full length (real data now)")
	t:eq(read_buf[0], 7, "Should have read real data (7)")
end

---@param t testing.T
function test.metadata_pcall(t)
	local underlying = {
		getSampleRate = function() error("Metadata failed") end,
		getChannelCount = function() return 2 end,
		getBytesPerSample = function() return 2 end,
		getDuration = function() return 10 end,
		secondsToBytes = function(_, s) return math.floor(s * 44100) * 2 * 2 end,
	}

	local buffered = BufferedDecoder(underlying, 1.0)

	t:eq(buffered:getSampleRate(), 44100, "Should fallback to default sample rate")
	t:eq(buffered:getDuration(), 0, "Should fallback to 0 duration")
end

---@param t testing.T
function test.reset_signal(t)
	local underlying = {
		getSampleRate = function() return 44100 end,
		getChannelCount = function() return 2 end,
		getBytesPerSample = function() return 2 end,
		getDuration = function() return 10 end,
		secondsToBytes = function(_, s) return math.floor(s * 44100) * 2 * 2 end,
		getDataString = function() error("ThreadRemote reset") end,
	}

	local buffered = BufferedDecoder(underlying, 1.0)

	-- First getData resumes preloader
	buffered:getData(ffi.new("int8_t[1024]"), 1024)

	-- Preloader should be dead now because of the reset error
	t:eq(coroutine.status(buffered.preloader_co), "dead", "Preloader should terminate on reset")
end

---@param t testing.T
function test.seek(t)
	local sample_rate = 44100
	local duration = 10
	local underlying = FakeDecoder(duration * sample_rate, sample_rate, 2)
	local buffered = BufferedDecoder(underlying, 1.0)

	local u_buf = ffi.cast("int8_t*", underlying.wave.byte_ptr)
	for i = 0, 100000 do u_buf[i] = i % 120 + 1 end -- Use +1 to avoid 0s

	buffered:setBytesPosition(50000)
	t:eq(buffered:getBytesPosition(), 50000)

	local read_len = 100
	local read_buf = ffi.new("int8_t[?]", read_len)

	-- Since FakeDecoder doesn't yield, setBytesPosition already triggered
	-- the preloader to seek and fill the buffer, so data is available immediately.
	buffered:getData(read_buf, read_len)

	t:eq(read_buf[0], 50000 % 120 + 1, "Data should match after seek")
end

---@param t testing.T
function test.negative_start(t)
	local SoftwareMixer = require("rizu.engine.audio.SoftwareMixer")
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
	local buffered = BufferedDecoder(mixer, 100)
	
	t:eq(buffered:getPosition(), -5, "Buffered should start at decoder's position (-5)")
	t:eq(buffered:getDuration(), 10, "Duration should match underlying decoder's duration")

	local buf = ffi.new("int16_t[20]")
	local read = buffered:getData(buf, 20)
	t:eq(read, 20, "Should read 20 bytes (10 seconds)")
	t:eq(buffered:getPosition(), 5, "Buffered position should be 5 after 10 seconds from -5")
	
	for i = 0, 9 do
		t:eq(buf[i], i + 1, "Sample " .. i .. " should be correct")
	end
end

return test
