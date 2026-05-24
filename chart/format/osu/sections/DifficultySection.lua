local KeyValue = require("chart.format.osu.sections.KeyValue")

---@class chart.osu.EditorSection: chart.osu.KeyValue
---@operator call: chart.osu.EditorSection
local DifficultySection = KeyValue + {}

DifficultySection.space = false

DifficultySection.HPDrainRate = "5"
DifficultySection.CircleSize = "4"
DifficultySection.OverallDifficulty = "5"
DifficultySection.ApproachRate = "5"
DifficultySection.SliderMultiplier = "1.4"
DifficultySection.SliderTickRate = "1"

DifficultySection.keys = {
	"HPDrainRate",
	"CircleSize",
	"OverallDifficulty",
	"ApproachRate",
	"SliderMultiplier",
	"SliderTickRate",
}

return DifficultySection
