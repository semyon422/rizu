local class = require("class")

---@class chart.ksm.SdvxButton
---@field time number Seconds relative to chart zero; audio starts at -offset.
---@field end_time number
---@field lane integer BT 1–4, FX 5–6.
---@field kind "chip"|"hold"

---@class chart.ksm.SdvxLaserSegment
---@field time number
---@field end_time number
---@field beat number Quarter-note beat at the source anchor.
---@field end_beat number
---@field from number Normalized knob coordinate, independent of extended rendering.
---@field to number
---@field slam boolean

---@class chart.ksm.SdvxLaser
---@field lane integer 1 or 2.
---@field extended boolean
---@field segments chart.ksm.SdvxLaserSegment[]

---@class chart.ksm.SdvxRow
---@field data string
---@field options {[string]: string}

---@class chart.ksm.SdvxChart
---@operator call: chart.ksm.SdvxChart
---@field buttons chart.ksm.SdvxButton[]
---@field lasers chart.ksm.SdvxLaser[]
---@field options {[string]: string}
---@field warnings string[] Ignored malformed header lines; note rows remain strict.
---@field tempos {time: number, beat: number, bpm: number}[]
local SdvxChart = class()
local positions = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmno"

---@param value string?
---@param label string
---@return number
local function number(value, label)
	local n = tonumber(value)
	assert(n and n == n and math.abs(n) < math.huge, "SDVX prototype: invalid " .. label .. ".")
	return n
end

---@param source string Normalized UTF-8 KSH source.
function SdvxChart:new(source)
	assert(#source <= 16 * 1024 * 1024, "SDVX prototype: source budget exceeded.")
	self.buttons, self.lasers, self.options, self.tempos = {}, {}, {}, {}
	self.warnings = {}
	---@type chart.ksm.SdvxRow[][]
	local measures = {}
	---@type chart.ksm.SdvxRow[]
	local rows = {}
	---@type {[string]: string}
	local pending = {}
	local body, count, line_number = false, 0, 0
	for line in (source:gsub("^\239\187\191", ""):gsub("\r\n", "\n") .. "\n"):gmatch("([^\n]*)\n") do
		line_number = line_number + 1
		---@cast line string
		line = line:match("^%s*(.-)%s*$")
		if line == "--" then
			if body then
				assert(#rows > 0, "SDVX prototype: empty measure.")
				measures[#measures + 1], rows = rows, {}
			end
			body = true
		elseif line ~= "" and line:sub(1, 2) ~= "//" and line:sub(1, 1) ~= "#" then
			---@type string?, string?
			local key, value = line:match("^([^=]+)=(.*)$")
			if key then
				if body then pending[key] = value else self.options[key] = value end
			elseif not body then
				self.warnings[#self.warnings + 1] = ("Ignored malformed KSH header line %d: %s"):format(line_number, line)
			else
				assert(line:match("^....|..|.."), "SDVX prototype: malformed note row.")
				count = count + 1
				assert(count <= 100000, "SDVX prototype: row budget exceeded.")
				rows[#rows + 1] = {data = line:sub(1, 10), options = pending}
				pending = {}
			end
		end
	end
	if #rows > 0 then measures[#measures + 1] = rows end
	assert(body and #measures > 0, "SDVX prototype: no measures.")
	assert(not next(pending), "SDVX prototype: trailing options without a row.")
	self.offset = self.options.o and number(self.options.o, "offset") / 1000 or 0
	self.audio_path = self.options.m and self.options.m:match("^([^;]+)")
	local bpm = number(measures[1][1].options.t or self.options.t, "initial BPM")
	assert(bpm > 0 and bpm <= 1000000, "SDVX prototype: unsupported BPM.")
	local signature = self.options.beat or "4/4"
	local time, beat = 0, 0
	---@type {[integer]: chart.ksm.SdvxButton}
	local holds = {}
	---@type {[integer]: {chain: chart.ksm.SdvxLaser, time: number, beat: number, source_time: number, source_beat: number, pos: number}}
	local active = {}
	local extended = {false, false}
	local objects = 0
	local function budget()
		objects = objects + 1
		assert(objects <= 100000, "SDVX prototype: object budget exceeded.")
	end
	---@param lane integer
	local function closeLaser(lane)
		local state = active[lane]
		if state then
			assert(#state.chain.segments > 0, "SDVX prototype: laser needs at least two anchors.")
			active[lane] = nil
		end
		extended[lane] = false
	end
	for _, measure in ipairs(measures) do
		signature = measure[1].options.beat or signature
		local numerator, denominator = signature:match("^(%d+)/(%d+)$")
		local n, d = number(numerator, "time signature"), number(denominator, "time signature")
		assert(n >= 1 and n <= 192 and d >= 1 and d <= 192, "SDVX prototype: unsupported time signature.")
		local step = n * 4 / d / #measure
		for row_index, row in ipairs(measure) do
			assert(row_index == 1 or not row.options.beat, "SDVX prototype: mid-measure signature change.")
			if row.options.t then bpm = number(row.options.t, "BPM") end
			assert(bpm > 0 and bpm <= 1000000, "SDVX prototype: unsupported BPM.")
			if #self.tempos == 0 or self.tempos[#self.tempos].bpm ~= bpm then
				self.tempos[#self.tempos + 1] = {time = time, beat = beat, bpm = bpm}
			end
			assert(not row.options.o, "SDVX prototype: mid-chart audio offset change.")
			for lane = 1, 6 do
				local c = row.data:sub(lane <= 4 and lane or lane + 1, lane <= 4 and lane or lane + 1)
				local chip = lane <= 4 and "1" or "2"
				local is_hold = lane <= 4 and c == "2" or lane > 4 and c ~= "0" and c ~= "2"
				assert(lane > 4 and c:match("^[1-9A-Z]$") or c == "0" or c == "1" or c == "2", "SDVX prototype: invalid button symbol.")
				if holds[lane] and not is_hold then
					holds[lane].end_time = time
					holds[lane] = nil
				end
				if c == chip or is_hold and not holds[lane] then
					budget()
					local object = {time = time, end_time = time, lane = lane, kind = c == chip and "chip" or "hold"}
					self.buttons[#self.buttons + 1] = object
					if is_hold then holds[lane] = object end
				end
			end
			for lane = 1, 2 do
				local range = row.options[lane == 1 and "laserrange_l" or "laserrange_r"]
				if range then
					assert(range == "2x" and not active[lane], "SDVX prototype: unsupported laser range change.")
					extended[lane] = true
				end
				local c = row.data:sub(8 + lane, 8 + lane)
				local state = active[lane]
				if c == "-" then
					closeLaser(lane)
				elseif c == ":" then
					assert(state, "SDVX prototype: laser continuation without an anchor.")
				else
					local index = positions:find(c, 1, true)
					assert(index, "SDVX prototype: invalid laser symbol.")
					local pos = (index - 1) / 50
					local next_time, next_beat = time, beat
					if state then
						budget()
						local slam = pos ~= state.pos and beat - state.source_beat <= 0.125 + 1e-9
						local start_time, start_beat = state.time, state.beat
						if slam then start_time, start_beat = state.source_time, state.source_beat end
						local segments = state.chain.segments
						local previous = segments[#segments]
						if previous and not previous.slam then
							previous.end_time, previous.end_beat = start_time, start_beat
						elseif previous and previous.time < start_time then
							budget()
							segments[#segments + 1] = {time = previous.time, end_time = start_time,
								beat = previous.beat, end_beat = start_beat, from = state.pos, to = state.pos, slam = false}
						end
						segments[#segments + 1] = {time = start_time, end_time = slam and start_time or time,
							beat = start_beat, end_beat = slam and start_beat or beat, from = state.pos, to = pos, slam = slam}
						if slam then next_time, next_beat = start_time, start_beat end
					else
						local chain = {lane = lane, extended = extended[lane], segments = {}}
						self.lasers[#self.lasers + 1] = chain
						state = {chain = chain, time = time, beat = beat, source_time = time, source_beat = beat, pos = pos}
						active[lane] = state
					end
					state.time, state.beat, state.pos = next_time, next_beat, pos
					state.source_time, state.source_beat = time, beat
				end
			end
			time, beat = time + step * 60 / bpm, beat + step
		end
	end
	for _, hold in pairs(holds) do hold.end_time = time end
	closeLaser(1); closeLaser(2)
	self.end_time = time
	assert(#self.buttons + #self.lasers > 0, "SDVX prototype: chart has no playable objects.")
end

return SdvxChart
