local Decoder = require("rizu.engine.audio.bass.Decoder")
local Wave = require("audio.Wave")
local ffi = require("ffi")
local bass = require("bass")

---@param duration number
---@return string
local function new_wave(duration)
	local wave = Wave()

	local samples_count = math.floor(wave.sample_rate * duration)

	wave:initBuffer(2, samples_count)
	for i = 0, samples_count - 1 do
		wave:setSampleFloat(i, 1, math.sin(i / samples_count * 1000))
		wave:setSampleFloat(i, 2, math.cos(i / samples_count * 1000))
	end

	return wave:encode()
end

local test = {}

do return test end

bass.init()

---@param t testing.T
function test.all(t)
	local duration = 0.1
	local size = 17640
	t:eq(size, math.floor(44100 * duration * 2 * 2))

	local data = new_wave(duration)

	local dec = Decoder(data)

	local buf_len = 17003 -- rounds to 17000
	local buf = ffi.new("uint8_t[?]", buf_len)

	t:eq(dec:getPosition(), 0)

	t:eq(dec:getData(buf, buf_len), 17000)
	t:lt(dec:getPosition() - 17000 / size * duration, 1e-9)

	t:eq(dec:getData(buf, buf_len), 640)
	t:eq(dec:getData(buf, buf_len), 0)
	t:eq(dec:getData(buf, buf_len), 0)

	t:eq(dec:getPosition(), duration)

	dec:setPosition(0.05)
	t:eq(dec:getPosition(), 0.05)
	t:eq(dec:getData(buf, buf_len), 8820)
	t:eq(dec:getPosition(), duration)

	dec:release()
end

return test
