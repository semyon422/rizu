local class = require("class")
local byte = require("byte_old")
local bit = require("bit")

---@class chart.o2jam.OJM
---@operator call: chart.o2jam.OJM
local OJM = class()

---@param pointer string|ffi.cdata*
---@param size number?
function OJM:new(pointer, size)
	if type(pointer) == "string" then
		self.buffer = byte.buffer(#pointer):fill(pointer):seek(0)
	else
		self.buffer = byte.buffer_t(pointer, size)
	end

	self.samples = {}
	self.acc_keybyte = 0xFF
	self.acc_counter = 0

	self:process()
end

OJM.mask_nami = {0x6E, 0x61, 0x6D, 0x69}
OJM.mask_0412 = {0x30, 0x34, 0x31, 0x32}

OJM.M30_SIGNATURE = 0x0030334D
OJM.OMC_SIGNATURE = 0x00434D4F
OJM.OJM_SIGNATURE = 0x004D4A4F

OJM.REARRANGE_TABLE = {
	0x10, 0x0E, 0x02, 0x09, 0x04, 0x00, 0x07, 0x01,
	0x06, 0x08, 0x0F, 0x0A, 0x05, 0x0C, 0x03, 0x0D,
	0x0B, 0x07, 0x02, 0x0A, 0x0B, 0x03, 0x05, 0x0D,
	0x08, 0x04, 0x00, 0x0C, 0x06, 0x0F, 0x0E, 0x10,
	0x01, 0x09, 0x0C, 0x0D, 0x03, 0x00, 0x06, 0x09,
	0x0A, 0x01, 0x07, 0x08, 0x10, 0x02, 0x0B, 0x0E,
	0x04, 0x0F, 0x05, 0x08, 0x03, 0x04, 0x0D, 0x06,
	0x05, 0x0B, 0x10, 0x02, 0x0C, 0x07, 0x09, 0x0A,
	0x0F, 0x0E, 0x00, 0x01, 0x0F, 0x02, 0x0C, 0x0D,
	0x00, 0x04, 0x01, 0x05, 0x07, 0x03, 0x09, 0x10,
	0x06, 0x0B, 0x0A, 0x08, 0x0E, 0x00, 0x04, 0x0B,
	0x10, 0x0F, 0x0D, 0x0C, 0x06, 0x05, 0x07, 0x01,
	0x02, 0x03, 0x08, 0x09, 0x0A, 0x0E, 0x03, 0x10,
	0x08, 0x07, 0x06, 0x09, 0x0E, 0x0D, 0x00, 0x0A,
	0x0B, 0x04, 0x05, 0x0C, 0x02, 0x01, 0x0F, 0x04,
	0x0E, 0x10, 0x0F, 0x05, 0x08, 0x07, 0x0B, 0x00,
	0x01, 0x06, 0x02, 0x0C, 0x09, 0x03, 0x0A, 0x0D,
	0x06, 0x0D, 0x0E, 0x07, 0x10, 0x0A, 0x0B, 0x00,
	0x01, 0x0C, 0x0F, 0x02, 0x03, 0x08, 0x09, 0x04,
	0x05, 0x0A, 0x0C, 0x00, 0x08, 0x09, 0x0D, 0x03,
	0x04, 0x05, 0x10, 0x0E, 0x0F, 0x01, 0x02, 0x0B,
	0x06, 0x07, 0x05, 0x06, 0x0C, 0x04, 0x0D, 0x0F,
	0x07, 0x0E, 0x08, 0x01, 0x09, 0x02, 0x10, 0x0A,
	0x0B, 0x00, 0x03, 0x0B, 0x0F, 0x04, 0x0E, 0x03,
	0x01, 0x00, 0x02, 0x0D, 0x0C, 0x06, 0x07, 0x05,
	0x10, 0x09, 0x08, 0x0A, 0x03, 0x02, 0x01, 0x00,
	0x04, 0x0C, 0x0D, 0x0B, 0x10, 0x05, 0x06, 0x0F,
	0x0E, 0x07, 0x09, 0x0A, 0x08, 0x09, 0x0A, 0x00,
	0x07, 0x08, 0x06, 0x10, 0x03, 0x04, 0x01, 0x02,
	0x05, 0x0B, 0x0E, 0x0F, 0x0D, 0x0C, 0x0A, 0x06,
	0x09, 0x0C, 0x0B, 0x10, 0x07, 0x08, 0x00, 0x0F,
	0x03, 0x01, 0x02, 0x05, 0x0D, 0x0E, 0x04, 0x0D,
	0x00, 0x01, 0x0E, 0x02, 0x03, 0x08, 0x0B, 0x07,
	0x0C, 0x09, 0x05, 0x0A, 0x0F, 0x04, 0x06, 0x10,
	0x01, 0x0E, 0x02, 0x03, 0x0D, 0x0B, 0x07, 0x00,
	0x08, 0x0C, 0x09, 0x06, 0x0F, 0x10, 0x05, 0x0A,
	0x04, 0x00
}

function OJM:process()
	self.signature = self.buffer:uint32_le()

	if self.signature == self.M30_SIGNATURE then
		self:parseM30()
	elseif self.signature == self.OMC_SIGNATURE then
		self:parseOMC(true)
	elseif self.signature == self.OJM_SIGNATURE then
		self:parseOMC(false)
	end
end

function OJM:parseM30()
	local buffer = self.buffer

	local file_format_version = buffer:int32_le()
	local encryption_flag = buffer:int32_le()
	local sample_count = buffer:int32_le()
	local sample_offset = buffer:int32_le()
	local payload_size = buffer:int32_le()
	local padding = buffer:int32_le()

	assert(buffer.offset == sample_offset)

	for i = 0, sample_count - 1 do
		if buffer.size - buffer.offset < 52 then
			break
		end

		local sample_name = buffer:cstring(32)

		if not sample_name:find(".") then sample_name = sample_name .. ".ogg" end

		local sample_size = buffer:int32_le()

		local codec_code = buffer:int16_le()
		local codec_code2 = buffer:int16_le()

		local music_flag = buffer:int32_le()
		local ref = buffer:int16_le()
		local unk_zero = buffer:int16_le()
		local pcm_samples = buffer:int32_le()

		if encryption_flag == 0 then
		elseif encryption_flag == 16 then
			self:M30_xor(self.mask_nami, sample_size)
		elseif encryption_flag == 32 then
			self:M30_xor(self.mask_0412, sample_size)
		end

		local value = ref
		if codec_code == 0 then
			value = 1000 + ref
		elseif codec_code ~= 5 then

		end
		self.samples[value] = buffer:string(sample_size)
	end
end

function OJM:M30_xor(mask, length)
	local buffer = self.buffer
	local pointer = buffer.pointer + buffer.offset
	for i = 0, length - 4, 4 do
		pointer[i + 0] = bit.bxor(pointer[i + 0], mask[1])
		pointer[i + 1] = bit.bxor(pointer[i + 1], mask[2])
		pointer[i + 2] = bit.bxor(pointer[i + 2], mask[3])
		pointer[i + 3] = bit.bxor(pointer[i + 3], mask[4])
	end
end

function OJM:parseOMC(decrypt)
	local buffer = self.buffer

	buffer:seek(4)

	local unk1 = buffer:int16_le()
	local unk2 = buffer:int16_le()
	local wav_start = buffer:int32_le()
	local ogg_start = buffer:int32_le()
	local filesize = buffer:int32_le()

	local file_offset = 20
	local sample_id = 0

	self.acc_keybyte = 0xFF
	self.acc_counter = 0

	while file_offset < ogg_start do
		buffer:seek(file_offset)
		file_offset = file_offset + 56

		local sample_name = buffer:cstring(32)

		if not sample_name:find(".") then sample_name = sample_name .. ".wav" end

		local audio_format = buffer:int16_le()
		local num_channels = buffer:int16_le()
		local sample_rate = buffer:int32_le()
		local bit_rate = buffer:int32_le()
		local block_align = buffer:int16_le()
		local bits_per_sample = buffer:int16_le()
		local data = buffer:int32_le()
		local chunk_size = buffer:int32_le()

		if chunk_size == 0 then
			sample_id = sample_id + 1
		else
			local headerTable = {
				"RIFF", -- ChunkID
				byte.int32_to_string_le(44 + chunk_size - 8), -- ChunkSize
				"WAVE", -- Format
				"fmt ", -- Subchunk1ID
				byte.int32_to_string_le(16), -- Subchunk1Size
				byte.int16_to_string_le(audio_format), -- AudioFormat
				byte.int16_to_string_le(num_channels), -- NumChannels
				byte.int32_to_string_le(sample_rate), -- SampleRate
				byte.int32_to_string_le(sample_rate * num_channels * bits_per_sample / 8), -- ByteRate
				byte.int16_to_string_le(block_align), -- BlockAlign
				byte.int16_to_string_le(bits_per_sample), -- BitsPerSample
				"data", -- Subchunk2ID
				byte.int32_to_string_le(chunk_size) -- Subchunk2Size
			}
			local headerString = table.concat(headerTable)
			assert(#headerString == 44)

			file_offset = file_offset + chunk_size

			local buf = byte.buffer(chunk_size)
			buf:fill(buffer:string(chunk_size))
			buf:seek(0)
			buffer:seek(buffer.offset - chunk_size)

			if decrypt then
				self:rearrange(buf, buffer)
				self:OMC_xor(buf)
			end

			self.samples[sample_id] = headerString .. buf:string(chunk_size)

			sample_id = sample_id + 1
		end
	end

	sample_id = 1000
	while file_offset < filesize do
		buffer:seek(file_offset)
		file_offset = file_offset + 36

		local sample_name = buffer:cstring(32)

		if not sample_name:find(".") then sample_name = sample_name .. ".ogg" end

		local sample_size = buffer:int32_le()

		if sample_size == 0 then
			sample_id = sample_id + 1
		else
			file_offset = file_offset + sample_size

			self.samples[sample_id] = buffer:string(sample_size)
			sample_id = sample_id + 1
		end
	end
end

function OJM:rearrange(buf, buffer)
	local length = tonumber(buf.size)
	local key = bit.lshift((length % 17), 4) + (length % 17)

	local block_size = math.floor(length / 17)

	for block = 0, 16 do
		local block_start_encoded = block_size * block
		local block_start_plain = block_size * self.REARRANGE_TABLE[key + 1]

		for i = 0, block_size - 1 do
			buf.pointer[block_start_plain + i] = buffer.pointer[buffer.offset + block_start_encoded + i]
		end

		key = key + 1
	end
end

function OJM:OMC_xor(buf)
	local temp
	local this_byte
	for i = 0, tonumber(buf.size) - 1 do
		temp = buf.pointer[i]
		this_byte = buf.pointer[i]

		if bit.band(bit.lshift(self.acc_keybyte, self.acc_counter), 0x80) ~= 0 then
			this_byte = bit.band(bit.bnot(this_byte), 0xff)
		end

		buf.pointer[i] = this_byte
		self.acc_counter = self.acc_counter + 1
		if self.acc_counter > 7 then
			self.acc_counter = 0
			self.acc_keybyte = temp
		end
	end
end

return OJM
