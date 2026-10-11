local ReplayBase = require("rizu.gameplay.ReplayBase")

---@class rizu.gameplay.sdvx.ReplayBase : rizu.gameplay.ReplayBase
---@operator call: rizu.gameplay.sdvx.ReplayBase
local SdvxReplayBase = ReplayBase + {}

SdvxReplayBase.mode = "sdvx"
SdvxReplayBase.formats = {"rizu-sdvx-1"}
SdvxReplayBase.directory = "sdvx"
SdvxReplayBase.max_event_id = 12

---Ids 11 and 12 are relative knob turns, the rest are buttons.
---@param event rizu.VirtualInputEvent
---@return boolean
function SdvxReplayBase:isValidEvent(event)
	if event.id >= 11 then
		return event.value == nil and event.pos ~= nil and event.pos[2] == 0
	end
	return ReplayBase.isValidEvent(self, event)
end

return SdvxReplayBase
