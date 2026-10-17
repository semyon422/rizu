local Enum = require("rdb.Enum")

---@enum (key) sea.ChartFormat
local ChartFormat = {
	sphere = 0,
	osu = 1,
	o2jam = 2,
	bms = 3,
	stepmania = 4,
	quaver = 5,
	midi = 6,
	ksm = 7,
	iidx = 8,
}

return Enum(ChartFormat)
