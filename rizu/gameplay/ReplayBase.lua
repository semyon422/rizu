local class = require("class")

---What a replay needs besides its frames, for gamemodes other than mania.
---Mania keeps sea.ReplayBase, which the server stores; both have `mode` and `rate`.
---@class rizu.gameplay.ReplayBase
---@operator call: rizu.gameplay.ReplayBase
---@field mode sea.Gamemode
---@field rate number
---@field rate_type sea.RateType
---@field format string Version of the recorded frames, one of `formats`.
local ReplayBase = class()

---Every version that can still be played, the current one last.
---@type string[]
ReplayBase.formats = {}

---Local replays are saved to userdata/replays/<directory>.
---@type string
ReplayBase.directory = nil

---@type integer
ReplayBase.max_event_id = 4

function ReplayBase:new()
	self.rate = 1
	self.rate_type = "linear"
	self.format = self.formats[#self.formats]
end

---Plain data for the chart worker thread; named like the sea.ReplayBase method.
---@param base table
function ReplayBase:exportReplayBase(base)
	base.mode = self.mode
	base.rate = self.rate
	base.rate_type = self.rate_type
	base.format = self.format
end

---@return true?
---@return string?
function ReplayBase:validate()
	local known = false
	for _, format in ipairs(self.formats) do
		known = known or format == self.format
	end
	if not known then
		return nil, "Incompatible replay format."
	end
	if type(self.rate) ~= "number" or not (self.rate >= 0.25 and self.rate <= 4) then
		return nil, "Invalid replay rate."
	end
	return true
end

---By default a frame is a button press or release.
---@param event rizu.VirtualInputEvent
---@return boolean
function ReplayBase:isValidEvent(event)
	return event.id >= 1 and type(event.value) == "boolean" and not event.pos
end

return ReplayBase
