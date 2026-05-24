local ChartAudio = require("rizu.engine.audio.ChartAudio")
local ChartFactory = require("chart.format.notechart.ChartFactory")

local cf = ChartFactory()
local test_chart_header = [[
# metadata
title Title
artist Artist
name Name
creator Creator
input 4key

# sounds
01 1.wav
02 2.wav
03 3.wav

# notes
]]

---@param notes string
---@return ncdk2.Chart
local function get_chart(notes)
	return assert(cf:getCharts("chart.sph", test_chart_header .. notes))[1].chart
end

local test = {}

---@param t testing.T
function test.basic(t)
	local ca = ChartAudio()

	local chart = get_chart([[
1000 =0 :0102 .5075
0100 =1 :0203 .2550
]])

	ca:load(chart)

	t:tdeq(ca.sounds, {
		{name = "2.wav", time = 0, volume = 0.75},
		{name = "3.wav", time = 1, volume = 0.5},
	})

	ca:new()
	ca:load(chart, true)

	t:tdeq(ca.sounds, {
		{name = "1.wav", time = 0, volume = 0.5},
		{name = "2.wav", time = 0, volume = 0.75},
		{name = "2.wav", time = 1, volume = 0.25},
		{name = "3.wav", time = 1, volume = 0.5},
	})
end

return test
