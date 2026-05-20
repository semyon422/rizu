local RefChart = require("chart.refchart.RefChart")
local Fraction = require("chart.core.Fraction")
local Chart = require("chart.model.Chart")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local Note = require("chart.model.notes.Note")
local Tempo = require("chart.model.to.Tempo")
local Measure = require("chart.model.to.Measure")
local Visual = require("chart.model.visual.Visual")
local Expand = require("chart.model.visual.Expand")
local Velocity = require("chart.model.visual.Velocity")
local Restorer = require("chart.refchart.Restorer")

local test = {}

function test.basic(t)
	local chart = Chart()

	chart.inputMode:set("4key")

	local layer = AbsoluteLayer()
	chart.layers.main = layer

	local visual = Visual()
	layer.visuals.main = visual

	local p = layer:getPoint(0)
	p._tempo = Tempo(120)
	p._measure = Measure(Fraction(1, 2))

	local vp_1 = visual:getPoint(p)
	vp_1._velocity = Velocity(2, 3, 4)
	vp_1._expand = Expand(1)

	local note_1 = Note(vp_1, "key1", "tap", 0, {sounds = {{"hit.ogg", 0.1}}})
	chart.notes:insert(note_1)

	local vp_2 = visual:newPoint(p)

	local note_2 = Note(vp_2, "key1", "tap", 0)
	chart.notes:insert(note_2)

	chart.resources:add("sound", "audio.ogg", "audio_fallback.ogg")

	chart:compute()

	local test_refchart = {
		inputmode = {key = 4},
		layers = {
			main = {
				points = {
					{
						measure = {1, 2},
						tempo = 120,
						time = 0,
					},
				},
				visuals = {
					main = {
						primaryTempo = 0,
						tempoMultiplyTarget = "current",
						points = {
							{
								point = 1,
								expand = 1,
								velocity = {2, 3, 4},
							},
							{
								point = 1
							},
						},
					},
				},
			},
		},
		notes = {
			{
				point = {
					index = 1,
					layer = "main",
					visual = "main",
				},
				column = "key1",
				type = "tap",
				weight = 0,
				data = {sounds = {{"hit.ogg", 0.1}}},
			},
			{
				point = {
					index = 2,
					layer = "main",
					visual = "main",
				},
				column = "key1",
				type = "tap",
				weight = 0,
				data = {},
			}
		},
		resources = {
			{"sound", "audio.ogg", "audio_fallback.ogg"},
		}
	}

	local refchart = RefChart(chart)

	t:tdeq(refchart, test_refchart)

	local restorer = Restorer()
	local _chart = restorer:restore(refchart)

	t:tdeq(RefChart(_chart), test_refchart)
end

return test
