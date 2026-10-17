local VisualNote = require("rizu.engine.visual.VisualNote")

---@class rizu.ShortVisualNote: rizu.VisualNote
---@operator call: rizu.ShortVisualNote
local ShortVisualNote = VisualNote + {}

ShortVisualNote.type = "short"

function ShortVisualNote:update()
	local visualPoint = self.linked_note.startNote.visualPoint
	local visualTime = self:getVisualTime(visualPoint)

	self.start_dt = self.visual_info:sub(visualTime)
end

ShortVisualNote.__lt = VisualNote.__lt

return ShortVisualNote
