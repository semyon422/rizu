local DanClear = require("sea.dan.DanClear")
local int_rates = require("chart.scoring.int_rates")
local stbl = require("stbl")

---@type rdb.ModelOptions
local dan_clears = {}

dan_clears.metatable = DanClear

dan_clears.types = {
	rate = int_rates,
	chartplay_ids = stbl,
}

return dan_clears
