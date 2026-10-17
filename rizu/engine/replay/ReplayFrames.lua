local zlib = require("zlib")
local valid = require("valid")
local types = require("sea.shared.types")
local BinaryEvents = require("rizu.engine.replay.BinaryEvents")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")

---@class rizu.ReplayFrame
---@field time number
---@field event rizu.VirtualInputEvent

---@class rizu.ReplayFrames
local ReplayFrames = {}

ReplayFrames.frame_struct = {
	time = types.number,
	event = valid.struct(VirtualInputEvent.struct),
}

---@param frames rizu.ReplayFrame[]
---@return string
function ReplayFrames.encode(frames)
	---@type rizu.BinaryEvent[]
	local binary_events = {}
	for i, frame in ipairs(frames) do
		local event = frame.event
		binary_events[i] = {
			time = frame.time,
			id = event.id,
			value = event.value,
			column = event.column,
			pos = event.pos,
		}
	end

	local data = BinaryEvents.encode(binary_events)
	local compressed_data = zlib.compress(data)

	return compressed_data
end

---@param data string
---@return rizu.ReplayFrame[]
function ReplayFrames.decode(data)
	local uncompressed_data = zlib.inflate(data)
	local binary_events = BinaryEvents.decode(uncompressed_data)

	---@type rizu.ReplayFrame[]
	local frames = {}
	for i, event in ipairs(binary_events) do
		frames[i] = {
			time = event.time,
			event = VirtualInputEvent(event.id, event.value, event.column, event.pos)
		}
	end

	return frames
end

return ReplayFrames
