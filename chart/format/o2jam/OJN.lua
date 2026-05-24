local class = require("class")
local ffi = require("ffi")
local bit = require("bit")
local byte = require("byte_old")
local Fraction = require("chart.core.Fraction")

---@class chart.o2jam.OJN
---@operator call: chart.o2jam.OJN
local OJN = class()

---@param ojnString string
function OJN:new(ojnString)
	self.buffer = byte.buffer_t(ffi.cast("unsigned char *", ojnString), #ojnString)
	self.charts = {{}, {}, {}}
	self:process()
	self.buffer = nil
end

OJN.genre_map = {
	"Ballad",
	"Rock",
	"Dance",
	"Techno",
	"Hip-hop",
	"Soul/R&B",
	"Jazz",
	"Funk",
	"Classical",
	"Traditional",
	"Etc"
}

function OJN:process()
	local buffer = self.buffer
	local encrypt = buffer:seek(0):string(3)
	if encrypt == "new" then
		self.buffer = self:decrypt()
	end

	self:readHeader()
	self.cover = self.buffer:seek(self.cover_offset):string(self.cover_size)
	for _, chart in ipairs(self.charts) do
		self:readChart(chart)
	end
end

-- https://github.com/SirusDoma/O2MusicList/blob/master/Source/Decoders/OJNDecoder.cs

---@return ffi.cdata*
function OJN:decrypt()
	local buffer = self.buffer
	buffer:seek(0)
	local input = buffer.pointer

	buffer:seek(3)
	local blockSize = buffer:uint8()
	local mainKey = buffer:uint8()
	local midKey = buffer:uint8()
	local initialKey = buffer:uint8()

	local encryptKeys = ffi.new("uint8_t[?]", blockSize, mainKey)
	encryptKeys[0] = initialKey
	encryptKeys[math.floor(blockSize / 2)] = midKey

	local outputBuffer = byte.buffer(buffer.size - buffer.offset)
	local output = outputBuffer.pointer
	for i = 0, tonumber(outputBuffer.size - 1), blockSize do
		for j = 0, blockSize - 1 do
			local offset = i + j
			if offset >= outputBuffer.size then
				return outputBuffer
			end

			output[offset] = bit.bxor(input[buffer.size - (offset + 1)], encryptKeys[j])
		end
	end

	return outputBuffer
end

function OJN:readHeader()
	local buffer = self.buffer
	buffer:seek(0)

	self.songid = buffer:int32_le()
	self.signature = buffer:cstring(4)
	assert(self.signature == "ojn", "Invalid OJN signature")

	self.encode_version = buffer:float_le()
	self.genre = buffer:int32_le()
	self.str_genre = self.genre_map[(self.genre < 0 or self.genre > 10) and 10 or self.genre]
	self.bpm = buffer:float_le()

	local charts = self.charts
	charts[1].level = buffer:int16_le()
	charts[2].level = buffer:int16_le()
	charts[3].level = buffer:int16_le()
	buffer:int16_le()

	charts[1].event_count = buffer:int32_le()
	charts[2].event_count = buffer:int32_le()
	charts[3].event_count = buffer:int32_le()

	charts[1].notes = buffer:int32_le()
	charts[2].notes = buffer:int32_le()
	charts[3].notes = buffer:int32_le()

	charts[1].measure_count = buffer:int32_le()
	charts[2].measure_count = buffer:int32_le()
	charts[3].measure_count = buffer:int32_le()

	charts[1].package_count = buffer:int32_le()
	charts[2].package_count = buffer:int32_le()
	charts[3].package_count = buffer:int32_le()

	self.old_encode_version = buffer:int16_le()
	self.old_songid = buffer:int16_le()
	self.old_genre = buffer:cstring(20)
	self.bmp_size = buffer:int32_le()
	self.file_version = buffer:int32_le()

	self.str_title = buffer:cstring(64)
	self.str_artist = buffer:cstring(32)
	self.str_noter = buffer:cstring(32)

	self.sample_file = buffer:cstring(32)
	self.ojm_file = self.sample_file

	self.cover_size = buffer:int32_le()

	charts[1].duration = buffer:int32_le()
	charts[2].duration = buffer:int32_le()
	charts[3].duration = buffer:int32_le()

	charts[1].note_offset = buffer:int32_le()
	charts[2].note_offset = buffer:int32_le()
	charts[3].note_offset = buffer:int32_le()
	self.cover_offset = buffer:int32_le()

	charts[1].note_offset_end = self.charts[2].note_offset
	charts[2].note_offset_end = self.charts[3].note_offset
	charts[3].note_offset_end = self.cover_offset
end

local channel_names = {
	[0] = "TIME_SIGNATURE",
	[1] = "BPM_CHANGE",
	[2] = "NOTE_1",
	[3] = "NOTE_2",
	[4] = "NOTE_3",
	[5] = "NOTE_4",
	[6] = "NOTE_5",
	[7] = "NOTE_6",
	[8] = "NOTE_7",
}

---@param chart table
function OJN:readChart(chart)
	local buffer = self.buffer:seek(chart.note_offset)

	local events = {}
	chart.event_list = events

	local total_events = chart.event_count

	while buffer.offset < chart.note_offset_end do
		if #events >= total_events then
			return
		end

		local measure = buffer:int32_le()
		local channel_number = buffer:int16_le()
		local events_count = buffer:int16_le()

		local channel = channel_names[channel_number] or "AUTO_PLAY"

		for i = 0, events_count - 1 do
			local position = Fraction(i, events_count)
			if channel == "BPM_CHANGE" or channel == "TIME_SIGNATURE" then
				local value = buffer:float_le()
				if value ~= 0 then
					table.insert(events, {
						channel = channel,
						measure = measure,
						position = position,
						value = value,
						type = "NONE"
					})
				end
			else
				local value = buffer:int16_le()
				local volume_pan = buffer:int8()
				local type = buffer:uint8()
				if value ~= 0 then
					local volume = bit.band(bit.rshift(volume_pan, 4), 0x0F) / 16
					if volume == 0 then volume = 1 end

					local pan = bit.band(volume_pan, 0x0F)
					if pan == 0 then pan = 8 end
					pan = pan - 8
					pan = pan / 8

					value = value - 1

					if type % 8 > 3 then
						value = value + 1000
					end
					type = type % 4

					local type_name = "NONE"
					if type == 2 then
						type_name = "HOLD"
					elseif type == 3 then
						type_name = "RELEASE"
					end

					table.insert(events, {
						channel = channel,
						measure = measure,
						position = position,
						value = value,
						type = type_name,
						volume = volume,
						pan = pan
					})
				end
			end
		end
	end
end

return OJN
