local class = require("class")

---@class chart.IChartDecoder
---@operator call: chart.IChartDecoder
local IChartDecoder = class()

IChartDecoder.hash = "00000000000000000000000000000000"

---@param s string
---@param hash string?
---@return {chart: chart.Chart, chartmeta: sea.Chartmeta}[]
function IChartDecoder:decode(s, hash)
	return {}
end

return IChartDecoder
