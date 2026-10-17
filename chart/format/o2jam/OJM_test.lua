local byte = require("byte")
local Fixtures = require("chart.format.o2jam.TestFixtures")
local OJM = require("chart.format.o2jam.OJM")

local test = {}

---@param s string
---@return byte.Buffer
local function buffer_from_string(s)
	local buffer = byte.buffer(#s)
	buffer:fill(s)
	buffer:seek(0)
	return buffer
end

---@param t testing.T
function test.parse_m30(t)
	local ojm = OJM(Fixtures.m30())

	t:eq(ojm.samples[42], "abcd1234")
end

---@param t testing.T
function test.parse_ojm(t)
	local ojm = OJM(Fixtures.ojm())

	t:eq(ojm.samples[0]:sub(1, 4), "RIFF")
	t:eq(ojm.samples[0]:sub(9, 12), "WAVE")
	t:eq(ojm.samples[0]:sub(37, 40), "data")
	t:eq(ojm.samples[0]:sub(45), "\x01\x02\x03\x04")
	t:eq(ojm.samples[1000], "OggSfixture")
end

---@param t testing.T
function test.parse_encrypted_omc_shape(t)
	local ojm = OJM(Fixtures.omc())

	t:eq(ojm.samples[0]:sub(1, 4), "RIFF")
	t:eq(ojm.samples[0]:sub(9, 12), "WAVE")
	t:eq(ojm.samples[0]:sub(37, 40), "data")
	t:eq(#ojm.samples[0], 48)
	t:eq(ojm.samples[1000], "OggSfixture")
end

---@param t testing.T
function test.omc_xor(t)
	local ojm = OJM(Fixtures.ojm())
	local data = "0123456789abcdef"
	local buf = buffer_from_string(data)

	ojm:OMC_xor(buf)
	buf:seek(0)
	t:eq(buf:string(#data), "\xcf\xce\xcd\xcc\xcb\xca\xc9\xc8\x38\x39\x9e\x9d\x63\x9b\x9a\x99")
end

---@param t testing.T
function test.rearrange_copies_expected_blocks(t)
	local ojm = OJM(Fixtures.ojm())
	local encoded = ("abcdefghijklmnopq"):rep(2)
	local source = buffer_from_string(encoded)
	local target = byte.buffer(#encoded)

	ojm:rearrange(target, source)
	target:seek(0)
	local decoded = target:string(#encoded)

	t:eq(#decoded, #encoded)
	t:ne(decoded, encoded)
end

return test
