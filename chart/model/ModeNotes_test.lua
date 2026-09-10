local ChartBuilder = require("chart.format.notechart.ChartBuilder")
local ModeNotes = require("chart.model.ModeNotes")
local RefChart = require("chart.refchart.RefChart")
local Restorer = require("chart.refchart.Restorer")
local test = {}

---@param t testing.T
function test.coincident_objects_and_nested_data_survive_snapshot(t)
	local builder = ChartBuilder()
	local chart = builder.chart
	ModeNotes.write(chart, builder:createAbsoluteLayer(), builder:getVisual("main"), "osu", {
		circle_size = 4,
		objects = {
			{time = 1, kind = "circle", x = 10},
			{time = 1, kind = "slider", x = 20, slider = {controls = {{x = 30, y = 40}}}},
		},
	})
	chart:compute()
	t:eq(chart.data.objects, nil)
	t:eq(#chart.notes.notes, 2)
	t:rawne(chart.notes.notes[1].visualPoint, chart.notes.notes[2].visualPoint)
	local ref = RefChart(chart)
	local restored = Restorer():restore(ref)
	local objects = ModeNotes.read(restored, "osu").objects
	t:eq(objects[1].x, 10)
	t:eq(objects[2].x, 20)
	t:eq(objects[2].slider.controls[1].y, 40)
	t:eq(restored.data.circle_size, 4)
	chart.data.circle_size = 9
	chart.notes.notes[2].data.slider.controls[1].y = 99
	t:eq(ref.data.circle_size, 4)
	t:eq(objects[2].slider.controls[1].y, 40)
	t:eq(ref.aim, nil)
	t:eq(restored.aim, nil)
end

return test
