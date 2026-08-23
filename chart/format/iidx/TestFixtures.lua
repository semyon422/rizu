local Ifs = require("chart.format.iidx.Ifs")
local byte = require("byte")
local bit = require("bit")

---@class chart.iidx.TestFixtures
local TestFixtures = {}

---@class chart.iidx.TestChartEvent
---@field tick integer
---@field type integer
---@field lane integer
---@field value integer?

---@class chart.iidx.TestMusicSong
---@field song_id integer
---@field title string
---@field title_ascii string?
---@field artist string
---@field genre string
---@field levels integer[]?
---@field volume integer?
---@field idents integer[]?
---@field bga_delay integer?
---@field bga_filename string?

---@type {[chart.iidx.VariationName]: integer}
local variation_sections = {
	SPH = 0,
	SPN = 1,
	SPA = 2,
	SPB = 3,
	SPL = 4,
	DPB = 5,
	DPH = 6,
	DPN = 7,
	DPA = 8,
	DPL = 10,
}

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
	s = tostring(s or "")
	return s:sub(1, len) .. string.rep("\0", math.max(len - #s, 0))
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

---@param tick integer
---@param typ integer
---@param lane integer
---@param value integer?
---@return string
local function chart_event(tick, typ, lane, value)
	local b = buffer(8)
	b:write("u32", tick)
	b:write("u8", typ)
	b:write("u8", lane)
	b:write("u16", value or 0)
	return buffer_string(b, 8)
end

---@param events chart.iidx.TestChartEvent[]
---@return string
local function chart_section(events)
	local out = {}
	for _, event in ipairs(events) do
		out[#out + 1] = chart_event(event.tick, event.type, event.lane, event.value)
	end
	out[#out + 1] = chart_event(0x7FFFFFFF, 6, 0, 0)
	return table.concat(out)
end

---@param sections {[chart.iidx.VariationName]: chart.iidx.TestChartEvent[]}
---@return string
function TestFixtures.chart1(sections)
	---@type {[integer]: string}
	local section_data = {}
	for name, events in pairs(sections) do
		section_data[variation_sections[name]] = chart_section(events)
	end

	local header_size = 12 * 8
	local offset = header_size
	local header = buffer(header_size)
	local bodies = {}
	for i = 0, 11 do
		local data = section_data[i]
		if data then
			header:write("u32", offset)
			header:write("u32", #data)
			bodies[#bodies + 1] = data
			offset = offset + #data
		else
			header:write("u32", 0)
			header:write("u32", 0)
		end
	end

	return buffer_string(header, header_size) .. table.concat(bodies)
end

---@param song_id integer
---@param chart_data string
---@param s3p_data string?
---@param extra_entries chart.iidx.IfsBuildEntry[]?
---@return string
function TestFixtures.ifs(song_id, chart_data, s3p_data, extra_entries)
	local dir = ("%05d"):format(song_id)
	local entries = {
		{path = dir .. "/" .. dir .. ".1", data = chart_data, time = 1234},
	}
	if s3p_data then
		entries[#entries + 1] = {path = dir .. "/" .. dir .. ".s3p", data = s3p_data, time = 1234}
	end
	for _, entry in ipairs(extra_entries or {}) do
		entries[#entries + 1] = entry
	end
	return Ifs.build(entries)
end

---@param values integer[]
---@return string
local function le32s(values)
	local out = {}
	for i, value in ipairs(values) do
		out[i] = string.char(
			value % 256,
			math.floor(value / 256) % 256,
			math.floor(value / 65536) % 256,
			math.floor(value / 16777216) % 256
		)
	end
	return table.concat(out)
end

---@param payload string
---@return string
local function s3v(payload)
	return "S3V0" .. le32s({32, #payload}) .. string.rep("\0", 20) .. payload
end

---@param payloads string[]
---@return string
function TestFixtures.s3p(payloads)
	local count = #payloads
	local offset = 8 + count * 8
	local entries = {}
	local data = {}
	for i, payload in ipairs(payloads) do
		local wrapped = s3v(payload)
		entries[i] = le32s({offset, #wrapped})
		data[i] = wrapped
		offset = offset + #wrapped
	end
	return "S3P0" .. le32s({count}) .. table.concat(entries) .. table.concat(data)
end

---@param name string
---@param len integer
---@return string
local function fixed_null(name, len)
	name = tostring(name or ""):sub(1, len)
	return name .. string.rep("\0", len - #name)
end

---@param v integer
---@return string
local function le16(v)
	if v < 0 then
		v = v + 0x10000
	end
	return string.char(v % 256, math.floor(v / 256) % 256)
end

---@param name string
---@param payloads string[]
---@return string
function TestFixtures.twoDx(name, payloads)
	local header_size = 72 + #payloads * 4
	local offset = header_size
	local offsets = {}
	for i, payload in ipairs(payloads) do
		offsets[i] = offset
		offset = offset + 24 + #payload
	end

	local out = {
		fixed_null(name, 16),
		le32s({header_size, #payloads}),
		string.rep("\0", 48),
	}
	for _, entry_offset in ipairs(offsets) do
		out[#out + 1] = le32s({entry_offset})
	end
	for _, payload in ipairs(payloads) do
		out[#out + 1] = "2DX9"
			.. le32s({24, #payload})
			.. le16(0x3231)
			.. le16(-1)
			.. le16(64)
			.. le16(1)
			.. le32s({0})
			.. payload
	end
	return table.concat(out)
end

---@param values integer[]
---@return string
local function level_bytes(values)
	local out = {}
	for i = 1, 10 do
		out[i] = string.char(values[i] or 0)
	end
	return table.concat(out)
end

---@param song chart.iidx.TestMusicSong
---@return string
local function music_entry(song)
	local out = {
		fixed(song.title, 0x40),
		fixed(song.title_ascii or song.title, 0x40),
		fixed(song.genre, 0x40),
		fixed(song.artist, 0x40),
		string.rep("\0", 20),
		string.rep("\0", 6),
		string.rep("\0", 6),
		level_bytes(song.levels or {}),
		string.rep("\0", 0x286),
	}

	local b = buffer(8)
	b:write("u32", song.song_id)
	b:write("u32", song.volume or 100)
	out[#out + 1] = buffer_string(b, 8)
	out[#out + 1] = u8s(song.idents or {48, 48, 48, 48, 48, 48, 48, 48, 48, 48})
	local bga_delay = buffer(2)
	bga_delay:write("i16", song.bga_delay or 0)
	out[#out + 1] = buffer_string(bga_delay, 2)
	out[#out + 1] = fixed(song.bga_filename, 0x20)
	out[#out + 1] = string.rep("\0", 4)
	out[#out + 1] = string.rep("\0", 0x20 * 10)
	out[#out + 1] = string.rep("\0", 4)

	return table.concat(out)
end

---@param songs chart.iidx.TestMusicSong[]
---@param version integer?
---@return string
function TestFixtures.musicdb(songs, version)
	local header = buffer(16)
	header:fill("IIDX")
	header:write("u32", version or 30)
	header:write("u16", #songs)
	header:write("u16", 0)
	header:write("u32", 0)

	local out = {buffer_string(header, 16)}
	for _, song in ipairs(songs) do
		out[#out + 1] = music_entry(song)
	end
	return table.concat(out)
end

---@param data string
---@return string
function TestFixtures.omnimixMusicDb(data)
	local key = "subnimix"
	local header = {}
	for i = 1, math.min(64, #data) do
		header[i] = string.char(bit.bxor(data:byte(i), key:byte((i - 1) % #key + 1)))
	end
	return table.concat(header) .. data:sub(65)
end

---@return string
function TestFixtures.sampleChart()
	return TestFixtures.chart1({
		SPN = {
			{tick = 0, type = 4, lane = 0, value = 150},
			{tick = 0, type = 5, lane = 4, value = 4},
			{tick = 0, type = 12, lane = 0, value = 0},
			{tick = 1500, type = 12, lane = 0, value = 0},
			{tick = 0, type = 0, lane = 0, value = 1},
			{tick = 750, type = 0, lane = 7, value = 2},
			{tick = 900, type = 7, lane = 0, value = 3},
		},
		DPN = {
			{tick = 0, type = 4, lane = 0, value = 150},
			{tick = 0, type = 12, lane = 0, value = 0},
			{tick = 1500, type = 12, lane = 0, value = 0},
			{tick = 0, type = 0, lane = 1, value = 1},
			{tick = 750, type = 1, lane = 2, value = 2},
			{tick = 900, type = 7, lane = 0, value = 3},
		},
	})
end

---@return string
function TestFixtures.sampleMusicDb()
	return TestFixtures.musicdb({
		{
			song_id = 1234,
			title = "Fixture Song",
			artist = "Fixture Artist",
			genre = "Fixture Genre",
			levels = {0, 3, 5, 0, 0, 0, 4, 6, 0, 0},
		},
		{
			song_id = 2222,
			title = "Missing Archive",
			artist = "Fixture Artist",
			genre = "Fixture Genre",
			levels = {0, 1, 0, 0, 0, 0, 0, 0, 0, 0},
		},
	})
end

return TestFixtures
