local Enum = require("rdb.Enum")

-- Stored in chart_patterns.pattern_1 and pattern_2, so never renumber one: retire it and add the next free value.
-- Grouped by skillset only to keep the list readable.
---@enum (key) chart.scoring.Pattern
local Pattern = {
	stream = 1,
	dumpstream = 2,
	index_stream = 3,
	jumptrill = 4,
	split_trill = 5,

	jumpstream = 6,
	light_jumpstream = 7,
	handstream = 8,
	dense_handstream = 9,
	chordstream = 10,
	dense_chordstream = 11,
	bracket = 12,
	quadstream = 13,

	chordjack = 14,
	dense_chordjack = 15,
	["4242chordjack"] = 16,
	jackhammer = 17,
	jumpjack = 18,
	speed_jack = 19,
	double_stairs = 20,

	technical = 21,
	delay = 22,
	inverse = 23,
	hybrid = 24,
	full_ln = 25,
}

return Enum(Pattern)
