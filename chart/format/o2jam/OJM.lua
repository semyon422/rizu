local class = require("class")
local byte = require("byte")
local bit = require("bit")
local Wave = require("audio.Wave")

---@class chart.o2jam.OJM
---@operator call: chart.o2jam.OJM
---@field buffer byte.Buffer
---@field samples {[integer]: string}
local OJM = class()

---@param s string
---@return byte.Buffer
local function buffer_from_string(s)
	local buffer = byte.buffer(#s)
	buffer:fill(s)
	buffer:seek(0)
	return buffer
end

---@param data string
function OJM:new(data)
	self.buffer = buffer_from_string(data)

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
	self.signature = self.buffer:read("u32")

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

	local file_format_version = buffer:read("i32")
	local encryption_flag = buffer:read("i32")
	local sample_count = buffer:read("i32")
	local sample_offset = buffer:read("i32")
	local payload_size = buffer:read("i32")
	local padding = buffer:read("i32")

	assert(buffer.offset == sample_offset)

	for i = 0, sample_count - 1 do
		if buffer.size - buffer.offset < 52 then
			break
		end

		local sample_name = buffer:string(32, true)

		if not sample_name:find(".") then sample_name = sample_name .. ".ogg" end

		local sample_size = buffer:read("i32")

		local codec_code = buffer:read("i16")
		local codec_code2 = buffer:read("i16")

		local music_flag = buffer:read("i32")
		local ref = buffer:read("i16")
		local unk_zero = buffer:read("i16")
		local pcm_samples = buffer:read("i32")

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
	local pointer = buffer.ptr + buffer.offset
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

	local unk1 = buffer:read("i16")
	local unk2 = buffer:read("i16")
	local wav_start = buffer:read("i32")
	local ogg_start = buffer:read("i32")
	local filesize = buffer:read("i32")

	local file_offset = 20
	local sample_id = 0

	self.acc_keybyte = 0xFF
	self.acc_counter = 0

	while file_offset < ogg_start do
		buffer:seek(file_offset)
		file_offset = file_offset + 56

		local sample_name = buffer:string(32, true)

		if not sample_name:find(".") then sample_name = sample_name .. ".wav" end

		local audio_format = buffer:read("i16")
		local num_channels = buffer:read("i16")
		local sample_rate = buffer:read("i32")
		local bit_rate = buffer:read("i32")
		local block_align = buffer:read("i16")
		local bits_per_sample = buffer:read("i16")
		local data = buffer:read("i32")
		local chunk_size = buffer:read("i32")

		if chunk_size == 0 then
			sample_id = sample_id + 1
		else
			local headerString = Wave.encodeHeader(num_channels, sample_rate, bits_per_sample / 8, chunk_size, audio_format)

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

		local sample_name = buffer:string(32, true)

		if not sample_name:find(".") then sample_name = sample_name .. ".ogg" end

		local sample_size = buffer:read("i32")

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
			buf.ptr[block_start_plain + i] = buffer.ptr[buffer.offset + block_start_encoded + i]
		end

		key = key + 1
	end
end

function OJM:OMC_xor(buf)
	local temp
	local this_byte
	for i = 0, tonumber(buf.size) - 1 do
		temp = buf.ptr[i]
		this_byte = buf.ptr[i]

		if bit.band(bit.lshift(self.acc_keybyte, self.acc_counter), 0x80) ~= 0 then
			this_byte = bit.band(bit.bnot(this_byte), 0xff)
		end

		buf.ptr[i] = this_byte
		self.acc_counter = self.acc_counter + 1
		if self.acc_counter > 7 then
			self.acc_counter = 0
			self.acc_keybyte = temp
		end
	end
end

return OJM
