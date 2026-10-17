local Encoding = require("chart.format.iidx.Encoding")
local bit = require("bit")

---@alias chart.iidx.VariationName
---| "SPB"
---| "SPN"
---| "SPH"
---| "SPA"
---| "SPL"
---| "DPB"
---| "DPN"
---| "DPH"
---| "DPA"
---| "DPL"

---@class chart.iidx.MusicDbEntry
---@field raw_offset integer
---@field raw_size integer
---@field song_id integer
---@field title string
---@field title_raw string
---@field title_ascii string
---@field title_ascii_raw string
---@field genre string
---@field genre_raw string
---@field artist string
---@field artist_raw string
---@field subtitle string?
---@field subtitle_raw string?
---@field levels {[chart.iidx.VariationName]: integer}
---@field idents {[chart.iidx.VariationName]: integer}
---@field volume integer
---@field bga_delay integer
---@field bga_filename string
---@field bga_filename_raw string
---@field afp_flag integer
---@field afp_data string[]

---@class chart.iidx.MusicDb
---@field magic "IIDX"
---@field version integer
---@field song_count integer
---@field index_count integer
---@field index {[integer]: integer}
---@field songs chart.iidx.MusicDbEntry[]
---@field by_id {[integer]: chart.iidx.MusicDbEntry}

---@class chart.iidx.MusicDbModule
local MusicDb = {}

local omni_header_key = "subnimix"
local omni_header_size = 64

---@param data string
---@return string
local function decode_omni_header(data)
	if data:sub(1, 4) == "IIDX" then
		return data
	end
	if #data < omni_header_size then
		return data
	end

	---@type string[]
	local header = {}
	for i = 1, omni_header_size do
		local key_byte = omni_header_key:byte((i - 1) % #omni_header_key + 1)
		header[i] = string.char(bit.bxor(data:byte(i), key_byte))
	end
	local decoded = table.concat(header) .. data:sub(omni_header_size + 1)
	if decoded:sub(1, 4) == "IIDX" then
		return decoded
	end
	return data
end

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
	local value = le16u(s, o)
	if value >= 0x8000 then
		return value - 0x10000
	end
	return value
end

---@param s string
---@param o integer
---@return integer
local function le32(s, o)
	local a, b, c, d = s:byte(o, o + 3)
	return a + b * 256 + c * 65536 + d * 16777216
end

---@param data string
---@param pos integer
---@param len integer
---@param encoding string?
---@return string
---@return string
---@return integer
local function read_str(data, pos, len, encoding)
	local raw = data:sub(pos, pos + len - 1)
	local text
	if encoding == "utf-16-le" then
		text = Encoding.utf16le_to_utf8(raw)
	else
		text = Encoding.cp932_to_utf8(raw)
	end
	return text, raw, pos + len
end

---@param data string
---@param pos integer
---@param version integer
---@return chart.iidx.MusicDbEntry
---@return integer
local function parse_entry(data, pos, version)
	local entry = {raw_offset = pos}
	---@cast entry chart.iidx.MusicDbEntry
	if version == 80 then
		entry.title, entry.title_raw, pos = read_str(data, pos, 0x80)
		entry.title_ascii, entry.title_ascii_raw, pos = read_str(data, pos, 0x40)
		entry.genre, entry.genre_raw, pos = read_str(data, pos, 0x80)
		entry.artist, entry.artist_raw, pos = read_str(data, pos, 0x80)
	elseif version >= 32 then
		entry.title, entry.title_raw, pos = read_str(data, pos, 0x100, "utf-16-le")
		entry.title_ascii, entry.title_ascii_raw, pos = read_str(data, pos, 0x40)
		entry.genre, entry.genre_raw, pos = read_str(data, pos, 0x80, "utf-16-le")
		entry.artist, entry.artist_raw, pos = read_str(data, pos, 0x100, "utf-16-le")
		entry.subtitle, entry.subtitle_raw, pos = read_str(data, pos, 0x100, "utf-16-le")
	else
		entry.title, entry.title_raw, pos = read_str(data, pos, 0x40)
		entry.title_ascii, entry.title_ascii_raw, pos = read_str(data, pos, 0x40)
		entry.genre, entry.genre_raw, pos = read_str(data, pos, 0x40)
		entry.artist, entry.artist_raw, pos = read_str(data, pos, 0x40)
	end

	entry.texture_title = le32(data, pos)
	entry.texture_artist = le32(data, pos + 4)
	entry.texture_genre = le32(data, pos + 8)
	entry.texture_load = le32(data, pos + 12)
	entry.texture_list = le32(data, pos + 16)
	pos = pos + 20
	if version >= 32 and version ~= 80 then
		entry.texture_subtitle = le32(data, pos)
		pos = pos + 4
	end

	entry.font_idx = le32(data, pos)
	entry.game_version = le16u(data, pos + 4)
	pos = pos + 6
	if version >= 32 and version ~= 80 then
		entry.other_folder = le16u(data, pos)
		entry.bemani_folder = le16u(data, pos + 2)
		entry.beginner_rec_folder = le16u(data, pos + 4)
		entry.iidx_rec_folder = le16u(data, pos + 6)
		entry.bemani_rec_folder = le16u(data, pos + 8)
		entry.splittable_diff = le16u(data, pos + 10)
		entry.unk_unused = le16u(data, pos + 12)
		pos = pos + 14
	else
		entry.other_folder = le16u(data, pos)
		entry.bemani_folder = le16u(data, pos + 2)
		entry.splittable_diff = le16u(data, pos + 4)
		pos = pos + 6
	end

	---@type chart.iidx.VariationName[]
	local names
	if version >= 27 then
		names = {"SPB", "SPN", "SPH", "SPA", "SPL", "DPB", "DPN", "DPH", "DPA", "DPL"}
	else
		names = {"SPN", "SPH", "SPA", "DPN", "DPH", "DPA", "SPB", "DPB"}
	end

	entry.levels = {}
	for i, name in ipairs(names) do
		local level = data:byte(pos + i - 1)
		entry[name .. "_level"] = level
		entry.levels[name] = level
	end
	if version < 27 then
		entry.SPL_level = 0
		entry.DPL_level = 0
		entry.levels.SPL = 0
		entry.levels.DPL = 0
	end
	pos = pos + (version >= 27 and 10 or 8)

	if version == 80 then
		pos = pos + 0x2c6
	elseif version >= 27 then
		pos = pos + 0x286
	else
		pos = pos + 0xa0
	end

	entry.song_id = le32(data, pos)
	entry.volume = le32(data, pos + 4)
	pos = pos + 8

	entry.idents = {}
	for i, name in ipairs(names) do
		local ident = data:byte(pos + i - 1)
		entry[name .. "_ident"] = ident
		entry.idents[name] = ident
	end
	if version < 27 then
		entry.SPL_ident = 48
		entry.DPL_ident = 48
		entry.idents.SPL = 48
		entry.idents.DPL = 48
	end
	pos = pos + (version >= 27 and 10 or 8)

	entry.bga_delay = le16s(data, pos)
	pos = pos + 2
	if version <= 26 or version == 80 then
		pos = pos + 2
	end
	entry.bga_filename, entry.bga_filename_raw, pos = read_str(data, pos, 0x20)
	if version == 80 then
		pos = pos + 2
	end
	entry.afp_flag = le32(data, pos)
	pos = pos + 4
	entry.afp_data = {}
	for i = 1, version >= 22 and 10 or 9 do
		local afp_data
		local _afp_data_raw
		afp_data, _afp_data_raw, pos = read_str(data, pos, 0x20)
		entry.afp_data[i] = afp_data
	end
	if version >= 26 then
		pos = pos + 4
	end
	entry.raw_size = pos - entry.raw_offset

	return entry, pos
end

---@param data string
---@return chart.iidx.MusicDb
function MusicDb.parse(data)
	data = decode_omni_header(data)
	assert(data:sub(1, 4) == "IIDX", "not an IIDX music database")
	local version = le32(data, 5)
	local song_count = le16u(data, 9)
	local a = le16u(data, 11)
	local b = le32(data, 13)
	local index_count = version >= 32 and b or a
	local index_entry_size = version >= 32 and 4 or 2
	local db = {
		magic = "IIDX",
		version = version,
		song_count = song_count,
		index_count = index_count,
		index = {},
		songs = {},
		by_id = {},
	}
	---@cast db chart.iidx.MusicDb

	local pos = 17
	for i = 0, index_count - 1 do
		db.index[i] = index_entry_size == 4 and le32(data, pos) or le16s(data, pos)
		pos = pos + index_entry_size
	end

	for _ = 1, song_count do
		local entry
		entry, pos = parse_entry(data, pos, version)
		db.songs[#db.songs + 1] = entry
		db.by_id[entry.song_id] = entry
	end

	return db
end

return MusicDb
