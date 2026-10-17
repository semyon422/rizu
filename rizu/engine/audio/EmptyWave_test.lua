local MixerSource = require("rizu.engine.audio.bass.MixerSource")
local EmptyWave = require("rizu.engine.audio.EmptyWave")
local Decoder = require("rizu.engine.audio.bass.Decoder")
local ffi = require("ffi")
local test = {}

local fmt = "fmt " .. string.char(16, 0, 0, 0, 1, 0, 1, 0, 68, 172, 0, 0, 136, 88, 1, 0, 2, 0, 16, 0)
local empty = "RIFF" .. string.char(36, 0, 0, 0) .. "WAVE" .. fmt .. "data\0\0\0\0"

---@param t testing.T
function test.empty_sample_decodes_as_silence_without_bass_stream(t)
	t:eq(#empty, 44)
	t:eq(EmptyWave.isEmpty(empty), true)
	t:eq(Decoder.probeDuration(empty), 0)
	local decoder = Decoder(empty, "float32")
	t:eq(decoder:getFrameDuration(), 0)
	t:eq(decoder:getFrames(ffi.new("float[2]"), 1), 0)
	decoder:setFramePosition(10)
	t:eq(decoder:getFramePosition(), 0)
	local silent = Decoder(empty, "float32")
	MixerSource.addSound({}, silent, 1)
	t:eq(silent.released, true)
	decoder:release(); decoder:release()
end

---@param t testing.T
function test.not_a_blanket_corruption_fallback(t)
	t:eq(EmptyWave.isEmpty(""), false)
	t:eq(EmptyWave.isEmpty(empty:sub(1, 43)), false)
	t:eq(EmptyWave.isEmpty(empty .. "garbage"), false)
	t:eq(EmptyWave.isEmpty(empty:gsub("data", "junk")), false)
	local nonempty = "RIFF" .. string.char(38, 0, 0, 0) .. "WAVE" .. fmt .. "data" .. string.char(2, 0, 0, 0, 0, 0)
	t:eq(EmptyWave.isEmpty(nonempty), false)
end

return test
