---@class chart.iidx.TwoDxEntry
---@field index integer
---@field offset integer
---@field size integer
---@field magic string
---@field header_size integer
---@field payload_offset integer
---@field payload_size integer
---@field wav_size integer
---@field track integer
---@field attenuation integer
---@field loop integer
---@field format string
---@field extension string

---@class chart.iidx.TwoDxArchive
---@field name string
---@field header_size integer
---@field count integer
---@field entries chart.iidx.TwoDxEntry[]
---@field data string

---@class chart.iidx.TwoDx
local TwoDx = {}

---@param s string
---@param o integer
---@return integer
local function le16u(s, o)
	local a, b = s:byte(o, o + 1)
	return a + b * 256
end

---@param s string
---@param o integer
---@return integer
local function le16s(s, o)
	local v = le16u(s, o)
	if v >= 0x8000 then
		return v - 0x10000
	end
	return v
end

---@param s string
---@param o integer
---@return integer
local function le32(s, o)
	local a, b, c, d = s:byte(o, o + 3)
	return a + b * 256 + c * 65536 + d * 16777216
end

---@param s string
---@return string
local function cstr16(s)
	local n = s:sub(1, 16)
	local z = n:find("\0", 1, true)
	return z and n:sub(1, z - 1) or n
end

---@param data string
---@return string format
---@return string extension
local function detect_payload(data)
	if data:sub(1, 4) == "RIFF" and data:sub(9, 12) == "WAVE" then
		return "riff/wav", "wav"
	elseif data:sub(1, 4) == "OggS" then
		return "ogg", "ogg"
	end
	return "unknown", "bin"
end

---@param data string
---@return chart.iidx.TwoDxArchive
function TwoDx.parse(data)
	assert(#data >= 76, "2dx data too short")
	local name = cstr16(data)
	local header_size = le32(data, 17)
	local count = le32(data, 21)
	assert(header_size == 72 + count * 4, "unrecognized 2dx header size")

	local archive = {
		name = name,
		header_size = header_size,
		count = count,
		entries = {},
		data = data,
	}
	---@cast archive chart.iidx.TwoDxArchive

	for i = 1, count do
		local table_pos = 73 + (i - 1) * 4
		local offset = le32(data, table_pos)
		local magic = data:sub(offset + 1, offset + 4)
		assert(magic == "2DX9", "unrecognized 2dx entry magic at " .. offset)
		local entry_header_size = le32(data, offset + 5)
		local wav_size = le32(data, offset + 9)
		local track = le16s(data, offset + 15)
		local attenuation = le16s(data, offset + 19)
		local loop = le32(data, offset + 21)
		local payload_offset = offset + entry_header_size
		local payload = data:sub(payload_offset + 1, payload_offset + wav_size)
		local format, extension = detect_payload(payload)
		archive.entries[#archive.entries + 1] = {
			index = i,
			offset = offset,
			size = entry_header_size + wav_size,
			magic = magic,
			header_size = entry_header_size,
			payload_offset = payload_offset,
			payload_size = wav_size,
			wav_size = wav_size,
			track = track,
			attenuation = attenuation,
			loop = loop,
			format = format,
			extension = extension,
		}
	end

	return archive
end

---@param archive chart.iidx.TwoDxArchive
---@param index integer
---@return string?
function TwoDx.payload(archive, index)
	local entry = archive.entries[index]
	if not entry then
		return nil
	end
	return archive.data:sub(entry.payload_offset + 1, entry.payload_offset + entry.payload_size)
end

return TwoDx
