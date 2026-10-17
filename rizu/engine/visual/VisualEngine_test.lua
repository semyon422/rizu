local VisualEngine = require("rizu.engine.visual.VisualEngine")
local VisualInfo = require("rizu.engine.visual.VisualInfo")
local TestChartFactory = require("sea.chart.TestChartFactory")

local tcf = TestChartFactory()

local test = {}

---@param t testing.T
function test.basic_short(t)
	local visual_info = VisualInfo()
	local ve = VisualEngine(visual_info)

	local res = tcf:create("4key", {
		{time = 0, column = 1},
		{time = 1, column = 2},
		{time = 2, column = 3},
	})

	ve:load(res.chart)

	visual_info.time = -1.001
	ve:update()
	t:eq(#ve.visible_notes, 0)

	visual_info.time = -1
	ve:update()
	t:eq(#ve.visible_notes, 1)

	visual_info.time = 0.999
	ve:update()
	t:eq(#ve.visible_notes, 2)

	visual_info.time = 1
	ve:update()
	t:eq(#ve.visible_notes, 2)

	visual_info.time = 2.001
	ve:update()
	t:eq(#ve.visible_notes, 1)

	visual_info.time = 3
	ve:update()
	t:eq(#ve.visible_notes, 0)
end

---@param t testing.T
function test.basic_long(t)
	local visual_info = VisualInfo()
	local ve = VisualEngine(visual_info)

	local res = tcf:create("4key", {
		{time = 0, column = 1, end_time = 4},
	})

	ve:load(res.chart)

	visual_info.time = -1.001
	ve:update()
	t:eq(#ve.visible_notes, 0)

	visual_info.time = -1
	ve:update()
	t:eq(#ve.visible_notes, 1)

	visual_info.time = 2
	ve:update()
	t:eq(#ve.visible_notes, 1)

	visual_info.time = 4.999
	ve:update()
	t:eq(#ve.visible_notes, 1)

	visual_info.time = 5
	ve:update()
	t:eq(#ve.visible_notes, 0)
end

---@param t testing.T
function test.sv_should_move_with_notes(t)
	local visual_info = VisualInfo()
	local ve = VisualEngine(visual_info)

	local res = tcf:create("4key", {
		{time = 0, velocity = {}},
		{time = 0.25, column = 2, velocity = {0.5}},
		{time = 0.75, column = 3, velocity = {}},
	})

	ve:load(res.chart)

	local notes = ve.visible_notes
	---@cast notes rizu.ShortVisualNote[]

	visual_info.time = 0
	ve:update()
	t:eq(#notes, 2)

	t:eq(notes[1].start_dt, -0.25)
	t:eq(notes[2].start_dt, -0.5)

	visual_info.time = 0.25
	ve:update()

	t:eq(notes[1].start_dt, 0)
	t:eq(notes[2].start_dt, -0.25)

	visual_info.time = 0.5
	ve:update()

	t:eq(notes[1].start_dt, 0.125)
	t:eq(notes[2].start_dt, -0.125)
end

return test
