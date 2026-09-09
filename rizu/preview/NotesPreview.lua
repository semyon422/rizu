local class = require("class")
local SphPreview = require("chart.format.sph.SphPreview")

---@class rizu.preview.PreviewNote
---@field time number
---@field end_time number

---@class rizu.preview.NotesPreview
---@operator call: rizu.preview.NotesPreview
---@field columns rizu.preview.PreviewNote[][]
---@field end_times number[][] Cumulative maximum end times for interval lookup.
local NotesPreview = class()

---@param data string
---@param column_count integer
function NotesPreview:new(data, column_count)
	assert(column_count > 0)
	self.columns = {}
	self.end_times = {}
	for i = 1, column_count do
		self.columns[i] = {}
		self.end_times[i] = {}
	end
	if data == "" then
		return
	end
	assert(#data >= 3 and data:byte(1) <= 1, "invalid preview header")
	local lines = SphPreview:decode(data)
	---@type number[]
	local beats = {}
	---@type {beat: number, time: number}[]
	local vertices = {}
	local beat = -1
	for i, line in ipairs(lines) do
		if not line.time then
			beat = beat + 1
		end
		local position = beat + (line.time and line.time:tonumber() or 0)
		assert(i == 1 or position >= beats[i - 1], "unordered preview lines")
		beats[i] = position
		if line.offset then
			local prev = vertices[#vertices]
			assert(not prev or position > prev.beat and line.offset >= prev.time, "invalid preview timing")
			vertices[#vertices + 1] = {beat = position, time = line.offset}
		end
	end
	assert(#vertices >= 2, "missing preview timing vertices")
	---@type {[integer]: rizu.preview.PreviewNote}
	local pressed = {}
	local vertex_index = 1
	for i, line in ipairs(lines) do
		local position = beats[i]
		while vertex_index < #vertices - 1 and position >= vertices[vertex_index + 1].beat do
			vertex_index = vertex_index + 1
		end
		local a, b = vertices[vertex_index], vertices[vertex_index + 1]
		local time = a.time + (position - a.beat) * (b.time - a.time) / (b.beat - a.beat)
		for column, press in pairs(line.notes or {}) do
			assert(column <= column_count, "invalid preview column")
			if press then
				local note = {time = time, end_time = time}
				local notes = self.columns[column]
				notes[#notes + 1] = note
				pressed[column] = note
			else
				local note = assert(pressed[column], "orphan preview release")
				note.end_time = time
				pressed[column] = nil
			end
		end
	end
	for column, notes in ipairs(self.columns) do
		local ends = self.end_times[column]
		local last = -math.huge
		for i, note in ipairs(notes) do
			last = math.max(last, note.end_time)
			ends[i] = last
		end
	end
end

-- Includes holds starting before the window, including after a backward seek.
---@param column integer
---@param from number
---@param to number
---@return integer first
---@return integer last
function NotesPreview:getVisibleRange(column, from, to)
	local notes, ends = self.columns[column], self.end_times[column]
	local lo, hi = 1, #notes + 1
	while lo < hi do
		local mid = math.floor((lo + hi) / 2)
		if ends[mid] < from then lo = mid + 1 else hi = mid end
	end
	local first = lo
	lo, hi = first, #notes + 1
	while lo < hi do
		local mid = math.floor((lo + hi) / 2)
		if notes[mid].time <= to then lo = mid + 1 else hi = mid end
	end
	return first, lo - 1
end

return NotesPreview
