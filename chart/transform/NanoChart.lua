local class = require("class")
local byte = require("byte")
local bit = require("bit")

---@class chart.NanoChart
---@operator call: chart.NanoChart
local NanoChart = class()

--[[
	header {
		uint8		version
		uint8[16]	hash
		uint8		inputCount -- need to convert to keys only
	}

	startObject {
		0001 .... .... .... / input = [1, 12], 0 is no object (see usage below), 14 is delay object, 15 is extended object
		     0... .... .... / 1 - press, 0 - release
		      0.. .... .... / 1 - at same time, 0 - at new time
		       00 0000 0000 / time fraction numerator, 1024 values, 0x000 -> 0 seconds, 0x3ff -> 1023/1024 seconds
	}

	nextObject {
		0001 .... / input = [1, 14]
		     0... / 1 - press, 0 - release
		      1.. / 1 - at same time, 0 - at new time
		       00 / unused bits
	}

	nextObjectExtended { -- always at same time, use 0-input object to define time
		1111 .... .... .... / object type, always 1111
		     0... .... .... / 1 - press, 0 - release
		      000 .... .... / unused bits
		          0000 0001 / input = [1, 255]
	}

	nextDelayObject {
		1110 .... / object type 14 == 1110 is delay object
			 0000 / delay = [0, 15] seconds (v1)
		     0000 / delay = [-8, 7] seconds (v2)
	}
]]

--[[
	version = 1
	hash = 0x00000000000000000000000000000000
	inputs = 4
	notes:	time	type	input
			0		p		1
			0		p		2
			2.25	r		2
			36		r		3
			36		p		255
			36.5	r		255

	0000 0001

	0000 0000 0000 0000 0000 0000 0000 0000
	0000 0000 0000 0000 0000 0000 0000 0000
	0000 0000 0000 0000 0000 0000 0000 0000
	0000 0000 0000 0000 0000 0000 0000 0000

	0000 0100

	0001 1100 0000 0000 -- 1st note
	0010 1100           -- 2nd note
	1110 0010			-- 2 seconds delay
	0010 0001 0000 0000 -- 3rd note
	1110 1111			-- 15 seconds delay
	1110 1111			-- 15 seconds delay
	1110 0010			-- 2 seconds delay
	0011 0000 0000 0000 -- 4th note
	1111 1000 1111 1111 -- 5th note
	0000 0010 0000 0000 -- 0-input note (+0.5)
	1111 0000 1111 1111 -- 6th note
]]

---@param input integer
---@param note_type integer
---@param same_time boolean?
---@param note_time number?
---@return string
function NanoChart:encodeNote(input, note_type, same_time, note_time)
	local prefix = ""
	if input > 12 then
		if not same_time then
			prefix = self:encodeNote(0, 0, false, note_time)
		end
		local same_time_bit = same_time and 4 or 0
		return prefix .. string.char(0xf0 + bit.lshift(note_type, 3) + same_time_bit, input)
	end

	local first_byte = bit.lshift(input, 4) + bit.lshift(note_type, 3)
	if same_time then
		return string.char(first_byte + 4)
	end

	local time = math.floor(assert(note_time) * 1024)
	first_byte = first_byte + bit.rshift(time, 8)
	return string.char(first_byte, bit.band(time, 0xff))
end

---@param hash string
---@param inputs number
---@param notes table
---@return string
function NanoChart:encode(hash, inputs, notes)
	-- table.sort(notes, sortNotes)

	local objects = {
		string.char(2),
		assert(#hash == 16 and hash),
		string.char(inputs)
	}

	local offset = 0
	local noteTime = 0
	local prevNoteTime
	for i = 1, #notes do
		local note = notes[i]

		local noteOffset = math.floor(note.time)
		while offset ~= noteOffset do
			local delta = math.min(math.max(noteOffset - offset, -8), 7)
			offset = offset + delta
			if delta < 0 then
				delta = delta + 16
			end
			objects[#objects + 1] = string.char(0xe0 + delta)
		end

		noteTime = note.time - math.floor(note.time)

		local prevNote = notes[i - 1]
		prevNoteTime = prevNote and prevNote.time - math.floor(prevNote.time)

		objects[#objects + 1] = self:encodeNote(
			note.input,
			note.type,
			prevNoteTime == noteTime,
			noteTime
		)
	end

	return table.concat(objects)
end

---@param content string
---@return number
---@return string
---@return number
---@return table
function NanoChart:decode(content)
	local buffer = byte.buffer(#content)
	buffer:fill(content):seek(0)

	local version = buffer:read("u8")
	local hash = buffer:string(16)
	local inputs = buffer:read("u8")

	local notes = {}

	local offset = 0
	local noteTime = 0
	while buffer.offset < buffer.size do
		local cbyte = buffer:read("u8")

		local input = bit.rshift(bit.band(cbyte, 0xf0), 4)
		if input == 14 then
			local delta = bit.band(cbyte, 0xf)
			if version == 2 and delta > 7 then
				delta = delta - 16
			end
			offset = offset + delta
		elseif input == 15 then
			notes[#notes + 1] = {
				time = offset + noteTime / 1024,
				type = bit.rshift(bit.band(cbyte, 0x08), 3),
				input = buffer:read("u8")
			}
		else
			local note_type = bit.rshift(bit.band(cbyte, 0x08), 3)
			local same_time = bit.band(cbyte, 0x04) ~= 0

			if not same_time then
				noteTime = bit.lshift(bit.band(cbyte, 0x03), 8) + buffer:read("u8")
			end

			if input ~= 0 then
				notes[#notes + 1] = {
					time = offset + noteTime / 1024,
					type = note_type,
					input = input
				}
			end
		end
	end

	return version, hash, inputs, notes
end

return NanoChart
