local ChartFactory = require("chart.format.notechart.ChartFactory")

local test = {}

local test_chart = [[
# metadata
title Title
artist Artist
name Name
creator Creator
audio audio.mp3
input 4key

# notes
1000 =0
- =1
]]

function test.basic(t)
	local cf = ChartFactory()

	local charts = assert(cf:getCharts("chart.sph", test_chart))
	t:eq(#charts, 1)
end

return test
