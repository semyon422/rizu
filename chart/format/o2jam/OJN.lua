local class = require("class")
local ffi = require("ffi")
local bit = require("bit")
local byte = require("byte")
local Fraction = require("chart.core.Fraction")

---@class chart.o2jam.OJNChart
---@field level integer
---@field event_count integer
---@field notes integer
---@field measure_count integer
---@field package_count integer
---@field duration integer
---@field note_offset integer
---@field note_offset_end integer
---@field event_list chart.o2jam.OJNEvent[]

---@class chart.o2jam.OJNEvent
---@field channel string
---@field measure integer
---@field position chart.Fraction
---@field value number
---@field type "NONE"|"HOLD"|"RELEASE"
---@field volume number?
---@field pan number?

---@class chart.o2jam.OJN
---@operator call: chart.o2jam.OJN
---@field buffer byte.Buffer
---@field charts chart.o2jam.OJNChart[]
local OJN = class()

---@param s string
---@return byte.Buffer
local function buffer_from_string(s)
	local buffer = byte.buffer(#s)
	buffer:fill(s)
	buffer:seek(0)
	return buffer
end

---@param ojnString string
function OJN:new(ojnString)
	self.buffer = buffer_from_string(ojnString)
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

---@return byte.Buffer
function OJN:decrypt()
	local buffer = self.buffer
	buffer:seek(0)
	local input = buffer.ptr

	buffer:seek(3)
	local blockSize = buffer:read("u8")
	local mainKey = buffer:read("u8")
	local midKey = buffer:read("u8")
	local initialKey = buffer:read("u8")

	local encryptKeys = ffi.new("uint8_t[?]", blockSize, mainKey)
	encryptKeys[0] = initialKey
	encryptKeys[math.floor(blockSize / 2)] = midKey

	local outputBuffer = byte.buffer(buffer.size - buffer.offset)
	local output = outputBuffer.ptr
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

	self.songid = buffer:read("i32")
	self.signature = buffer:string(4, true)
	assert(self.signature == "ojn", "Invalid OJN signature")

	self.encode_version = buffer:read("f32")
	self.genre = buffer:read("i32")
	self.str_genre = self.genre_map[(self.genre < 0 or self.genre > 10) and 10 or self.genre]
	self.bpm = buffer:read("f32")

	local charts = self.charts
	charts[1].level = buffer:read("i16")
	charts[2].level = buffer:read("i16")
	charts[3].level = buffer:read("i16")
	buffer:read("i16")

	charts[1].event_count = buffer:read("i32")
	charts[2].event_count = buffer:read("i32")
	charts[3].event_count = buffer:read("i32")

	charts[1].notes = buffer:read("i32")
	charts[2].notes = buffer:read("i32")
	charts[3].notes = buffer:read("i32")

	charts[1].measure_count = buffer:read("i32")
	charts[2].measure_count = buffer:read("i32")
	charts[3].measure_count = buffer:read("i32")

	charts[1].package_count = buffer:read("i32")
	charts[2].package_count = buffer:read("i32")
	charts[3].package_count = buffer:read("i32")

	self.old_encode_version = buffer:read("i16")
	self.old_songid = buffer:read("i16")
	self.old_genre = buffer:string(20, true)
	self.bmp_size = buffer:read("i32")
	self.file_version = buffer:read("i32")

	self.str_title = buffer:string(64, true)
	self.str_artist = buffer:string(32, true)
	self.str_noter = buffer:string(32, true)

	self.sample_file = buffer:string(32, true)
	self.ojm_file = self.sample_file

	self.cover_size = buffer:read("i32")

	charts[1].duration = buffer:read("i32")
	charts[2].duration = buffer:read("i32")
	charts[3].duration = buffer:read("i32")

	charts[1].note_offset = buffer:read("i32")
	charts[2].note_offset = buffer:read("i32")
	charts[3].note_offset = buffer:read("i32")
	self.cover_offset = buffer:read("i32")

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

---@param chart chart.o2jam.OJNChart
function OJN:readChart(chart)
	local buffer = self.buffer:seek(chart.note_offset)

	local events = {}
	chart.event_list = events

	local total_events = chart.event_count

	while buffer.offset < chart.note_offset_end do
		if #events >= total_events then
			return
		end

		local measure = buffer:read("i32")
		local channel_number = buffer:read("i16")
		local events_count = buffer:read("i16")

		local channel = channel_names[channel_number] or "AUTO_PLAY"

		for i = 0, events_count - 1 do
			local position = Fraction(i, events_count)
			if channel == "BPM_CHANGE" or channel == "TIME_SIGNATURE" then
				local value = buffer:read("f32")
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
				local value = buffer:read("i16")
				local volume_pan = buffer:read("i8")
				local type = buffer:read("u8")
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
