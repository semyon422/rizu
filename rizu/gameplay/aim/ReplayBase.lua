local ReplayBase = require("rizu.gameplay.ReplayBase")

---@class rizu.gameplay.aim.ReplayBase : rizu.gameplay.ReplayBase
---@operator call: rizu.gameplay.aim.ReplayBase
local AimReplayBase = ReplayBase + {}

AimReplayBase.mode = "osu"
-- Each version added a mechanic; older replays are played without the later ones.
AimReplayBase.formats = {
	"rizu-aim-circles-1",
	"rizu-aim-sliders-1",
	"rizu-aim-spinners-1",
	"rizu-aim-stacking-1",
	"rizu-aim-tracking-1",
}
AimReplayBase.directory = "aim"

---@return boolean
function AimReplayBase:hasStacking()
	return self.format == "rizu-aim-stacking-1" or self.format == "rizu-aim-tracking-1"
end

---@return boolean
function AimReplayBase:hasTracking()
	return self.format == "rizu-aim-tracking-1"
end

---Id 0 is pointer movement, the buttons carry the pointer position too.
---@param event rizu.VirtualInputEvent
---@return boolean
function AimReplayBase:isValidEvent(event)
	return true
end

return AimReplayBase
