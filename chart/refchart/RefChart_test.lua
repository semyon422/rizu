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

---@return chart.Chart
local function createChartWithNoteData()
	local chart = Chart()

	chart.inputMode:set("4key")

	local layer = AbsoluteLayer()
	chart.layers.main = layer

	local visual = Visual()
	layer.visuals.main = visual

	local p = layer:getPoint(0)
	local vp = visual:getPoint(p)

	local note = Note(vp, "key1", "tap", 0, {
		sounds = {
			{"hit.ogg", 0.1},
		},
	})
	chart.notes:insert(note)

	chart:compute()

	return chart
end

---@param t testing.T
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

---@param t testing.T
function test.note_data_is_snapshotted(t)
	local chart = createChartWithNoteData()
	local refchart = RefChart(chart)

	chart.notes.notes[1].data.sounds[1][1] = "mutated.ogg"

	t:eq(refchart.notes[1].data.sounds[1][1], "hit.ogg")
	t:rawne(refchart.notes[1].data, chart.notes.notes[1].data)
	t:rawne(refchart.notes[1].data.sounds[1], chart.notes.notes[1].data.sounds[1])
end

---@param t testing.T
function test.restored_note_data_is_isolated(t)
	local refchart = RefChart(createChartWithNoteData())
	local chart = Restorer():restore(refchart)

	refchart.notes[1].data.sounds[1][1] = "mutated.ogg"

	t:eq(chart.notes.notes[1].data.sounds[1][1], "hit.ogg")
	t:rawne(chart.notes.notes[1].data, refchart.notes[1].data)
	t:rawne(chart.notes.notes[1].data.sounds[1], refchart.notes[1].data.sounds[1])
end

---@param t testing.T
function test.measure_offset_is_snapshotted(t)
	local chart = Chart()

	chart.inputMode:set("4key")

	local layer = AbsoluteLayer()
	chart.layers.main = layer

	local visual = Visual()
	layer.visuals.main = visual

	local p = layer:getPoint(0)
	local offset = {1, 2}
	p._measure = Measure(offset)

	visual:getPoint(p)

	chart:compute()

	local refchart = RefChart(chart)

	offset[1] = 3
	offset[2] = 4

	t:tdeq(refchart.layers.main.points[1].measure, {1, 2})
	t:rawne(refchart.layers.main.points[1].measure, offset)
end

---@param t testing.T
function test.inputmode_is_snapshotted(t)
	local chart = Chart()

	chart.inputMode:set("4key")

	local refchart = RefChart(chart)

	chart.inputMode.key = 6

	t:tdeq(refchart.inputmode, {key = 4})
	t:rawne(refchart.inputmode, chart.inputMode)
end

---@param t testing.T
function test.restored_measure_offset_is_isolated(t)
	local chart = Chart()

	chart.inputMode:set("4key")

	local layer = AbsoluteLayer()
	chart.layers.main = layer

	local visual = Visual()
	layer.visuals.main = visual

	local p = layer:getPoint(0)
	p._measure = Measure(Fraction(1, 2))

	visual:getPoint(p)

	chart:compute()

	local refchart = RefChart(chart)
	local restored_chart = Restorer():restore(refchart)
	local restored_point = restored_chart.layers.main:getPointList()[1]

	refchart.layers.main.points[1].measure[1] = 3
	refchart.layers.main.points[1].measure[2] = 4

	t:tdeq(restored_point._measure.offset, {1, 2})
	t:rawne(restored_point._measure.offset, refchart.layers.main.points[1].measure)
end

return test
