local bit = require("bit")
local byte = require("byte")

---@class chart.o2jam.TestFixtures
local TestFixtures = {}

---@class chart.o2jam.TestNoteEvent
---@field value integer
---@field volume_pan integer
---@field type integer

---@param size integer
---@return byte.Buffer
local function buffer(size)
	local b = byte.buffer(size)
	b:gc(true)
	return b
end

---@param b byte.Buffer
---@param size integer
---@return string
local function buffer_string(b, size)
	b:seek(0)
	return b:string(size)
end

---@param s string
---@param len integer
---@return string
local function fixed(s, len)
	s = tostring(s or ""):sub(1, len)
	return s .. string.rep("\0", len - #s)
end

---@param values integer[]
---@return string
local function u8s(values)
	local out = {}
	for i, value in ipairs(values) do
		out[i] = string.char(value)
	end
	return table.concat(out)
end

---@param value integer
---@return string
local function i16(value)
	local b = buffer(2)
	b:write("i16", value)
	return buffer_string(b, 2)
end

---@param value integer
---@return string
local function i32(value)
	local b = buffer(4)
	b:write("i32", value)
	return buffer_string(b, 4)
end

---@param value number
---@return string
local function f32(value)
	local b = buffer(4)
	b:write("f32", value)
	return buffer_string(b, 4)
end

---@param plain string
---@return string
local function encrypt_ojn(plain)
	local block_size = 4
	local main_key = 0x24
	local mid_key = 0x42
	local initial_key = 0x11
	local keys = {initial_key, main_key, mid_key, main_key}
	local encrypted = {}
	for offset = 0, #plain - 1 do
		local key = keys[offset % block_size + 1]
		local encrypted_offset = #plain - offset
		encrypted[encrypted_offset] = string.char(bit.bxor(plain:byte(offset + 1), key))
	end
	return "new" .. u8s({block_size, main_key, mid_key, initial_key}) .. table.concat(encrypted)
end

---@param measure integer
---@param channel integer
---@param values number[]|chart.o2jam.TestNoteEvent[]
---@param is_float boolean?
---@return string
local function chart_package(measure, channel, values, is_float)
	local out = {i32(measure), i16(channel), i16(#values)}
	for _, value in ipairs(values) do
		if is_float then
			---@cast value number
			out[#out + 1] = f32(value)
		else
			---@cast value chart.o2jam.TestNoteEvent
			out[#out + 1] = i16(value.value)
			out[#out + 1] = string.char(value.volume_pan)
			out[#out + 1] = string.char(value.type)
		end
	end
	return table.concat(out)
end

---@return string
function TestFixtures.ojn()
	local chart1 = table.concat({
		chart_package(0, 1, {150, 0}, true),
		chart_package(1, 0, {750}, true),
		chart_package(2, 2, {
			{value = 5, volume_pan = 0, type = 2},
			{value = 5, volume_pan = 0x88, type = 3},
		}),
		chart_package(3, 9, {
			{value = 2, volume_pan = 0xF0, type = 4},
		}),
	})
	local cover = "cover"
	local header_size = 300
	local note_offset_1 = header_size
	local note_offset_2 = note_offset_1 + #chart1
	local note_offset_3 = note_offset_2
	local cover_offset = note_offset_3

	local header = table.concat({
		i32(1234), fixed("ojn", 4), f32(2.9), i32(1), f32(128),
		i16(3), i16(7), i16(12), i16(0),
		i32(5), i32(0), i32(0),
		i32(3), i32(0), i32(0),
		i32(4), i32(0), i32(0),
		i32(4), i32(0), i32(0),
		i16(1), i16(1234), fixed("old", 20), i32(0), i32(1),
		fixed("Fixture Title", 64),
		fixed("Fixture Artist", 32),
		fixed("Fixture Noter", 32),
		fixed("fixture.ojm", 32),
		i32(#cover),
		i32(120000), i32(0), i32(0),
		i32(note_offset_1), i32(note_offset_2), i32(note_offset_3), i32(cover_offset),
	})
	assert(#header == header_size)
	return header .. chart1 .. cover
end

---@return string
function TestFixtures.encryptedOjn()
	return encrypt_ojn(TestFixtures.ojn())
end

---@param signature string
---@return string
local function omc(signature)
	local wav = "\x01\x02\x03\x04"
	local ogg = "OggSfixture"
	local ogg_start = 20 + 56 + #wav
	local filesize = ogg_start + 36 + #ogg
	return table.concat({
		signature,
		i16(0), i16(0), i32(20), i32(ogg_start), i32(filesize),
		fixed("hit", 32),
		i16(1), i16(1), i32(44100), i32(44100), i16(1), i16(8), i32(0), i32(#wav),
		wav,
		fixed("music.ogg", 32), i32(#ogg), ogg,
	})
end

---@return string
function TestFixtures.ojm()
	return omc("OJM\0")
end

---@return string
function TestFixtures.omc()
	return omc("OMC\0")
end

---@return string
function TestFixtures.m30()
	local payload = "abcd1234"
	local mask = {0x6E, 0x61, 0x6D, 0x69}
	local encrypted = {}
	for i = 1, #payload do
		encrypted[i] = string.char(bit.bxor(payload:byte(i), mask[(i - 1) % 4 + 1]))
	end

	local sample_offset = 28
	return table.concat({
		"M30\0",
		i32(0), i32(16), i32(1), i32(sample_offset), i32(#payload), i32(0),
		fixed("sample", 32), i32(#payload), i16(5), i16(0), i32(0), i16(42), i16(0), i32(0),
		table.concat(encrypted),
	})
end

return TestFixtures
