local NanoChart = require("chart.transform.NanoChart")
local zlib = require("zlib")

---@alias sea.ReplayEvent {[1]: number, [2]: integer, [3]: boolean}

---@class sea.ReplayEvents
local ReplayEvents = {}

local hash = string.char(0):rep(16)

---@param events sea.ReplayEvent[]
---@return string
function ReplayEvents.encode(events)
	---@type {time: number, type: 1|0, input: integer}[]
	local notes = {}
	for i, event in ipairs(events) do
		notes[i] = {
			time = event[1],
			input = event[2],
			type = event[3] and 1 or 0,
		}
	end

	local data = NanoChart:encode(hash, 0, notes)
	local compressed_data = zlib.compress(data)

	return compressed_data
end

---@param data string
---@return sea.ReplayEvent[]
function ReplayEvents.decode(data)
	local uncompressed_data = zlib.inflate(data)
	local _, _, _, notes = NanoChart:decode(uncompressed_data)
	---@cast notes {time: number, type: 1|0, input: integer}[]

	---@type sea.ReplayEvent[]
	local events = {}
	for i, note in ipairs(notes) do
		events[i] = {note.time, note.input, note.type == 1}
	end

	return events
end

return ReplayEvents
