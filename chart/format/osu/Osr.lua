local class = require("class")
local bit = require("bit")
local byte = require("byte")
local leb128 = require("leb128")
local _7z = require("7z")

---@alias chart.osu.OsrEvent {[1]: integer, [2]: integer, [3]: integer, [4]: integer}

---@class chart.osu.Osr
---@operator call: chart.osu.Osr
---@field events chart.osu.OsrEvent[]
local Osr = class()

---@type chart.osu.OsrEvent
Osr.last_event = {-12345, 0, 0, 0}

local WIN_EPOCH = 621355968000000000

function Osr:new()
	self.mode = 3
	self.version = tonumber(os.date("%Y%m%d")) -- yyyymmdd
	self.beatmap_hash = "00000000000000000000000000000000"
	self.player_name = "Player"
	self.replay_hash = "00000000000000000000000000000000"
	self._300 = 0
	self._100 = 0
	self._50 = 0
	self.gekis = 0 -- Max 300s in mania
	self.katus = 0 -- 200s in mania
	self.misses = 0
	self.score = 0
	self.combo = 0
	self.pfc = 0
	self.mods = 0
	self.life_bar_graph = ""
	self.timestamp = WIN_EPOCH -- Windows ticks
	self.replay_length = 0
	self.comp_replay = ""
	self.uncomp_replay = ""
	self.lzma_props = string.char(93, 0, 0, 32, 0)
	self.online_score_id = 0
	self.additional_mod_info = nil ---@type number?
	self.events = {}

	self:setTimestamp(os.time())
end

---@param b byte.Buffer
local function read_string(b)
	local a = b:read("i8")
	if a == 0x00 then
		return ""
	end
	assert(a == 0x0b)

	local bytes, length = leb128.udec(b:cur())
	b:seek(b.offset + bytes)

	return b:string(length)
end

---@param b byte.Buffer
---@param s string
local function write_string(b, s)
	if s == "" then
		b:write("i8", 0x00)
		return
	end
	b:write("i8", 0x0b)

	local bytes = leb128.uenc(b:cur(), #s)
	b:seek(b.offset + bytes)

	b:fill(s)
end

---@param replay_data string
---@return chart.osu.OsrEvent[]
local function decode_replay_events(replay_data)
	local events = {}
	for dt, x, y, km in replay_data:gmatch("([^,^|]+)|([^,^|]+)|([^,^|]+)|([^,^|]+),") do ---@diagnostic disable-line: no-unknown
		table.insert(events, {
			tonumber(dt),
			tonumber(x),
			tonumber(y),
			tonumber(km),
		})
	end
	return events
end

---@param events chart.osu.OsrEvent[]
---@return string
local function encode_replay_events(events)
	---@type string[]
	local out = {}
	for i, e in ipairs(events) do
		out[i] = ("%s|%s|%s|%s,"):format(e[1], e[2], e[3], e[4])
	end
	return table.concat(out)
end

---@param s string
function Osr:decode(s)
	local b = byte.buffer(#s)
	b:fill(s):seek(0)

	self.mode = b:read("i8")
	self.version = b:read("i32")
	self.beatmap_hash = read_string(b)
	self.player_name = read_string(b)
	self.replay_hash = read_string(b)
	self._300 = b:read("i16")
	self._100 = b:read("i16")
	self._50 = b:read("i16")
	self.gekis = b:read("i16")
	self.katus = b:read("i16")
	self.misses = b:read("i16")
	self.score = b:read("i32")
	self.combo = b:read("i16")
	self.pfc = b:read("i8")
	self.mods = b:read("i32")
	self.life_bar_graph = read_string(b)
	self.timestamp = b:read("i64")

	local replay_length = b:read("i32") ---@type integer
	local comp_replay = b:string(replay_length) ---@type string
	local uncomp_replay, lzma_props = _7z.decode_s(comp_replay)
	self.lzma_props = lzma_props
	self.events = decode_replay_events(uncomp_replay)

	self.online_score_id = b:read("i64")
	if b.offset < b.size then
		self.additional_mod_info = b:read("f64") -- Target Practice accuracy
	end
end

---@return string
function Osr:encode()
	local b = byte.buffer(1024) -- header buffer

	b:write("i8", self.mode)
	b:write("i32", self.version)
	write_string(b, self.beatmap_hash)
	write_string(b, self.player_name)
	write_string(b, self.replay_hash)
	b:write("i16", self._300)
	b:write("i16", self._100)
	b:write("i16", self._50)
	b:write("i16", self.gekis)
	b:write("i16", self.katus)
	b:write("i16", self.misses)
	b:write("i32", self.score)
	b:write("i16", self.combo)
	b:write("i8", self.pfc)
	b:write("i32", self.mods)
	write_string(b, self.life_bar_graph)
	b:write("i64", self.timestamp)

	local uncomp_replay = encode_replay_events(self.events)
	local comp_replay = _7z.encode_s(uncomp_replay, self.lzma_props)

	b:write("i32", #comp_replay)

	local replay_data_offset = b.offset ---@type integer

	b:write("i64", self.online_score_id)
	if self.additional_mod_info then
		b:write("f64", self.additional_mod_info)
	end

	local end_header_offset = b.offset ---@type integer

	---@type string[]
	local out = {}

	b:seek(0)
	out[1] = b:string(replay_data_offset)
	out[2] = comp_replay
	b:seek(replay_data_offset)
	out[3] = b:string(end_header_offset - replay_data_offset)

	return table.concat(out)
end

---@return integer
function Osr:getTimestamp()
	return (self.timestamp - WIN_EPOCH) / 1e7
end

---@param ts integer
function Osr:setTimestamp(ts)
	self.timestamp = ts * 1e7 + WIN_EPOCH
end

function Osr:decodeManiaEvents()
	---@type {[1]: integer, [2]: integer, [3]: boolean}[]
	local mania_events = {}
	local i = 0
	local t = 0
	local prev_x = 0
	---@type boolean[]
	local keys = {}
	for _, e in ipairs(self.events) do
		local dt, x = e[1], e[2]
		if dt == -12345 then
			break
		end
		t = t + dt
		if x ~= prev_x then
			prev_x = x
			local key = 0
			while x > 0 do
				key = key + 1
				local pressed = bit.band(x, 1) ~= 0
				if pressed and not keys[key] then
					keys[key] = true
					i = i + 1
					mania_events[i] = {t, key, true}
				end
				x = bit.rshift(x, 1)
			end
			x = e[2]
			for _key in pairs(keys) do
				if bit.band(x, bit.lshift(1, _key - 1)) == 0 then
					keys[_key] = nil
					i = i + 1
					mania_events[i] = {t, _key, false}
				end
			end
		end
	end
	return mania_events
end

---@param mania_events {[1]: integer, [2]: integer, [3]: boolean}[]
function Osr:encodeManiaEvents(mania_events)
	---@type osu.OsrEvent[]
	local events = {}
	self.events = events

	local y = 19.17098
	local km = 0

	---@type integer
	local old_t
	local x = 0

	---@type osu.OsrEvent
	local event

	for _, me in ipairs(mania_events) do
		local t, key, state = me[1], me[2], me[3]

		if t ~= old_t then
			event = {t - (old_t or 0), x, y, km}
			table.insert(events, event)
			old_t = t
		end

		local key_bit = bit.lshift(1, key - 1)
		if state then
			x = bit.bor(x, key_bit)
		else
			x = bit.band(x, bit.bnot(key_bit))
		end
		event[2] = x
	end

	table.insert(events, self.last_event)
end

return Osr
