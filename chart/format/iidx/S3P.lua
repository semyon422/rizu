---@class chart.iidx.S3PSample
---@field index integer
---@field offset integer
---@field size integer
---@field magic string?
---@field header_size integer?
---@field payload_size integer?
---@field payload_offset integer?
---@field checksum string?
---@field format string?
---@field extension string?

---@class chart.iidx.S3PPack
---@field magic string
---@field count integer
---@field samples chart.iidx.S3PSample[]
---@field data string

---@class chart.iidx.S3P
local S3P = {}

---@param s string
---@param o integer
---@return integer
local function le32(s, o)
	local a, b, c, d = s:byte(o, o + 3)
	return a + b * 256 + c * 65536 + d * 16777216
end

---@param data string
---@return string format
---@return string extension
local function detect_payload(data)
	if data:sub(1, 16) == string.char(
		0x30, 0x26, 0xb2, 0x75, 0x8e, 0x66, 0xcf, 0x11,
		0xa6, 0xd9, 0x00, 0xaa, 0x00, 0x62, 0xce, 0x6c
	) then
		return "asf/wma", "wma"
	elseif data:sub(1, 4) == "RIFF" then
		return "riff/wav", "wav"
	elseif data:sub(1, 4) == "OggS" then
		return "ogg", "ogg"
	end
	return "unknown", "bin"
end

---@param data string
---@return chart.iidx.S3PPack
function S3P.parse(data)
	assert(data:sub(1, 4) == "S3P0", "not an S3P0 file")
	local count = le32(data, 5)
	---@type chart.iidx.S3PSample[]
	local samples = {}
	local pack = {
		magic = "S3P0",
		count = count,
		samples = samples,
		data = data,
	}
	---@cast pack chart.iidx.S3PPack

	for i = 1, count do
		local entry_offset = 9 + (i - 1) * 8
		local offset = le32(data, entry_offset)
		local size = le32(data, entry_offset + 4)
		local sample = {
			index = i,
			offset = offset,
			size = size,
		}
		---@cast sample chart.iidx.S3PSample

		if offset > 0 and size > 0 then
			sample.magic = data:sub(offset + 1, offset + 4)
			if sample.magic == "S3V0" and size >= 32 then
				sample.header_size = le32(data, offset + 5)
				sample.payload_size = le32(data, offset + 9)
				sample.checksum = data:sub(offset + 13, offset + 16)
				if sample.header_size <= 0 or sample.header_size > size then
					sample.header_size = 32
				end
				sample.payload_offset = offset + sample.header_size
				if sample.payload_size <= 0 or sample.payload_size > size - sample.header_size then
					sample.payload_size = size - sample.header_size
				end
			else
				sample.header_size = 0
				sample.payload_offset = offset
				sample.payload_size = size
			end
			local payload = S3P.sample_payload({data = data, samples = {[i] = sample}}, i)
			sample.format, sample.extension = detect_payload(payload)
		end

		samples[#samples + 1] = sample
	end

	return pack
end

---@param pack chart.iidx.S3PPack
---@param index integer
---@return string?
function S3P.sample_payload(pack, index)
	local sample = pack.samples[index]
	if not sample or not sample.payload_offset or not sample.payload_size then
		return nil
	end
	return pack.data:sub(sample.payload_offset + 1, sample.payload_offset + sample.payload_size)
end

---@param pack chart.iidx.S3PPack
---@param sample_id integer
---@return string?
function S3P.sample_payload_by_id(pack, sample_id)
	if sample_id <= 0 then
		return nil
	end
	return S3P.sample_payload(pack, sample_id)
end

return S3P
