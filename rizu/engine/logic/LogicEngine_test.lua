local LogicEngine = require("rizu.engine.logic.LogicEngine")
local LogicInfo = require("rizu.engine.logic.LogicInfo")
local TestChartFactory = require("sea.chart.TestChartFactory")

local tcf = TestChartFactory()

local test = {}

---@param t testing.T
function test.no_notes(t)
	local h = LogicEngine(LogicInfo())

	t:has_not_error(h.update, h)
end

---@param t testing.T
function test.track_active_notes(t)
	local logic_info = LogicInfo()
	logic_info.timing_values:setSimple(1)

	local le = LogicEngine(logic_info)

	local res = tcf:create("4key", {
		{time = 0, column = 1},
		{time = 1, column = 2},
		{time = 2, column = 1},
		{time = 3, column = 2},
		{time = 4, column = 1},
		{time = 5, column = 2},
	})

	le:load(res.chart)

	logic_info.time = -1.001
	le:update()
	t:eq(le:getActiveNotesCount(), 2)

	logic_info.time = -1
	le:update()
	t:eq(le:getActiveNotesCount(), 3)

	logic_info.time = 0.999
	le:update()
	t:eq(le:getActiveNotesCount(), 4)

	logic_info.time = 1
	le:update()
	t:eq(le:getActiveNotesCount(), 5)

	logic_info.time = 2.001
	le:update()
	t:eq(le:getActiveNotesCount(), 4)

	logic_info.time = 10
	le:update()
	t:eq(le:getActiveNotesCount(), 0)
end

---@param t testing.T
function test.simple_logic_note_auto_clear(t)
	local logic_info = LogicInfo()
	local le = LogicEngine(logic_info)

	local res = tcf:create("4key", {
		{time = 1, column = 1, type = "shade"},
	})

	le:load(res.chart)

	-- Note added at t=0 (with default 1s scroll range)
	logic_info.time = 0
	le:update()
	t:eq(le:getActiveNotesCount(), 1)
	
	-- Note should be passed at t=1
	logic_info.time = 1.0
	le:update()
	t:eq(le:getActiveNotesCount(), 0)
end

return test
