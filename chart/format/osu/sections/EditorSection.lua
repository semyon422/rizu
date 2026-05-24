local KeyValue = require("chart.format.osu.sections.KeyValue")

---@class chart.osu.EditorSection: chart.osu.KeyValue
---@operator call: chart.osu.EditorSection
local EditorSection = KeyValue + {}

EditorSection.space = true

EditorSection.DistanceSpacing = "1"
EditorSection.BeatDivisor = "4"
EditorSection.GridSize = "4"
EditorSection.TimelineZoom = "1"

EditorSection.keys = {
	"DistanceSpacing",
	"BeatDivisor",
	"GridSize",
	"TimelineZoom",
}

return EditorSection
