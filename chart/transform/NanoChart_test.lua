local NanoChart = require("chart.transform.NanoChart")

local test = {}

local function tohex(s)
	return (s:gsub(".", function(c)
		return ("%02x"):format(c:byte())
	end))
end

---@param t testing.T
function test.encode_note_preserves_binary_format(t)
	t:eq(tohex(NanoChart:encodeNote(1, 0, false, 0.125)), "1080")
	t:eq(tohex(NanoChart:encodeNote(12, 1, true)), "cc")
	t:eq(tohex(NanoChart:encodeNote(128, 0, false, 1 / 128)), "0008f080")
	t:eq(tohex(NanoChart:encodeNote(128, 0, true)), "f480")
end

---@param t testing.T
function test.encode_decode_roundtrip(t)
	local hash = "0123456789abcdef"
	local notes = {
		{time = 0, type = 1, input = 1},
		{time = 0, type = 1, input = 2},
		{time = 2.25, type = 0, input = 2},
		{time = 36, type = 0, input = 3},
		{time = 36, type = 1, input = 255},
		{time = 36.5, type = 0, input = 255},
	}

	local encoded = NanoChart:encode(hash, 4, notes)
	local version, decoded_hash, inputs, decoded_notes = NanoChart:decode(encoded)

	t:eq(version, 2)
	t:eq(decoded_hash, hash)
	t:eq(inputs, 4)
	t:tdeq(decoded_notes, notes)
end

---@param t testing.T
function test.decode_version_one_positive_delays(t)
	local content = string.char(1) .. string.rep("\0", 16) .. string.char(4, 0xe9, 0x10, 0)
	local version, _, inputs, notes = NanoChart:decode(content)

	t:eq(version, 1)
	t:eq(inputs, 4)
	t:tdeq(notes, {{time = 9, type = 0, input = 1}})
end

return test
