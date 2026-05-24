local KeyValue = require("chart.format.osu.sections.KeyValue")

---@class chart.osu.GeneralSection: chart.osu.KeyValue
---@operator call: chart.osu.GeneralSection
local GeneralSection = KeyValue + {}

GeneralSection.space = true

GeneralSection.AudioFilename = "virtual"
GeneralSection.AudioLeadIn = "0"
GeneralSection.PreviewTime = "-1"
GeneralSection.Countdown = "0"
GeneralSection.SampleSet = "0"
GeneralSection.StackLeniency = "0"
GeneralSection.Mode = "3"
GeneralSection.LetterboxInBreaks = "0"

GeneralSection.keys = {
	"AudioFilename",
	"AudioLeadIn",
	"PreviewTime",
	"Countdown",
	"SampleSet",
	"StackLeniency",
	"Mode",
	"LetterboxInBreaks",
}

return GeneralSection
