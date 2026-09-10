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
---@return chart.Chart
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

---@param t testing.T
function test.type_punctuation_does_not_determine_playability(t)
	local chart = get_chart("1000 =0 :01 .50\n0100 =1 :01 .50\n")
	chart.notes.notes[2].data.sounds = nil
	local note = chart.notes.notes[1]
	note.type = "custom:sample"
	local audio = ChartAudio()
	audio:load(chart)
	t:eq(#audio.sounds, 1)
	note.type = "osu:circle"
	audio = ChartAudio()
	audio:load(chart)
	t:eq(#audio.sounds, 0)
	audio:load(chart, true)
	t:eq(#audio.sounds, 1)
end

return test
