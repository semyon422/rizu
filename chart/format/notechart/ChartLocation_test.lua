local ChartLocation = require("chart.format.notechart.ChartLocation")

local test = {}

function test.basic(t)
	local cl = ChartLocation()

	t:assert(cl:isRelated("file.osu"))
	t:assert(cl:isRelated("file.BMS"))
	t:assert(not cl:isRelated("file.ojn"))
	t:assert(not cl:isRelated("file.midi"))
	t:assert(cl:isUnrelated("file.ojn"))

	t:assert(not cl:isRelated("file.ogg"))
	t:assert(not cl:isUnrelated("file.ogg"))
end

return test
