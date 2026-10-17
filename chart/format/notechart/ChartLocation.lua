local class = require("class")
local table_util = require("table_util")
local path_util = require("path_util")

---@class chart.ChartLocation
---@operator call: chart.ChartLocation
local ChartLocation = class()

local Unrelated = table_util.invert({
	"ojn",
	"mid",
	"midi",
})

local Related = table_util.invert({
	"osu",
	"bms",
	"bme",
	"bml",
	"pms",
	"qua",
	"ksh",
	"sph",
	"sm",
	"ssc",
	"1",
})

---@param filename string
---@return boolean
function ChartLocation:isUnrelated(filename)
	return Unrelated[path_util.ext(filename, true)] ~= nil
end

---@param filename string
---@return boolean
function ChartLocation:isRelated(filename)
	return Related[path_util.ext(filename, true)] ~= nil
end

return ChartLocation
