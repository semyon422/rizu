local InputEngine = require("rizu.engine.input.InputEngine")
local ActiveInputNotes = require("rizu.engine.input.ActiveInputNotes")
local LogicInfo = require("rizu.engine.logic.LogicInfo")
local TapLogicNote = require("rizu.engine.logic.notes.TapLogicNote")
local SimpleLogicNote = require("rizu.engine.logic.notes.SimpleLogicNote")
local HoldLogicNote = require("rizu.engine.logic.notes.HoldLogicNote")
local TestChartFactory = require("sea.chart.TestChartFactory")

local tcf = TestChartFactory()

local test = {}

---@param t testing.T
function test.non_matchable_note_should_not_intercept_input(t)
	local logic_info = LogicInfo()
	logic_info.timing_values = {
		hit = function() return "exactly" end,
		getMaxTime = function() return 1 end,
		getMinTime = function() return -1 end,
	}

	local res = tcf:create("4key", {
		{time = 0.5, column = 1}, -- Fake/Shade note at 0.5s
		{time = 1.0, column = 1}, -- Tap note at 1.0s
	})

	local notes = res.chart.notes:getLinkedNotes()

	-- Manually create logic notes
	-- We need to mock some methods because LogicNote expects more info
	local fake_note = SimpleLogicNote(notes[1], logic_info)
	local tap_note = TapLogicNote(notes[2], logic_info)

	local active_logic_notes = {fake_note, tap_note}
	local active_input_notes = ActiveInputNotes(active_logic_notes)
	active_input_notes:setInputMap(res.chart.inputMode:getInputMap())

	local ie = InputEngine(active_input_notes)

	-- Simulation at t=0.5
	logic_info.time = 0.5

	-- Input for column 1
	local event = {column = 1, value = true, id = 1}
	local note, catched = ie:receive(event)

	t:eq(catched, true)
	t:ne(note, nil)
	t:eq(note.logic_note, tap_note, "Input should be matched to tap note, skipping fake note")
	t:eq(tap_note.state, "passed")
	t:eq(fake_note.state, "clear", "Fake note should not have received input")
end

return test
