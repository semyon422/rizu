local HoldLogicNote = require("rizu.engine.logic.notes.HoldLogicNote")
local table_util = require("table_util")
local LogicInfo = require("rizu.engine.logic.LogicInfo")
local Note = require("chart.model.notes.Note")
local LinkedNote = require("chart.model.notes.LinkedNote")
local AbsolutePoint = require("chart.model.tp.AbsolutePoint")
local VisualPoint = require("chart.model.visual.VisualPoint")

local function new_test_ctx()
	local logic_info = LogicInfo(0, 1)
	logic_info.timing_values:setSimple(1, 2)

	local start_point = AbsolutePoint(0)
	local end_point = AbsolutePoint(10)

	local start_visual_point = VisualPoint(start_point)
	local end_visual_point = VisualPoint(end_point)

	local start_note = Note(start_visual_point, "key1", "hold", 1)
	local end_note = Note(end_visual_point, "key1", "hold", -1)

	local linked_note = LinkedNote(start_note, end_note)

	local logic_note = HoldLogicNote(linked_note, logic_info)

	local events = logic_info.note_changes

	return {
		logic_info = logic_info,
		start_point = start_point,
		end_point = end_point,
		start_visual_point = start_visual_point,
		end_visual_point = end_visual_point,
		start_note = start_note,
		end_note = end_note,
		linked_note = linked_note,
		logic_note = logic_note,
		events = events,
		clear_events = function() table_util.clear(events) end,
	}
end

local test = {}

---@param t testing.T
function test.too_early(t)
	local ctx = new_test_ctx()

	ctx.logic_info.time = -3
	ctx.logic_note:update()
	ctx.logic_note:input(true)

	t:tdeq(ctx.events, {{
		index = 0,
		type = "hold",
		time = -3,
		delta_time = -3,
		old_state = "clear",
		new_state = "clear",
	}})
	ctx.clear_events()
end

---@param t testing.T
function test.too_late(t)
	local ctx = new_test_ctx()

	ctx.logic_info.time = 3
	ctx.logic_note:update()

	t:tdeq(ctx.events, {{
		index = 0,
		type = "hold",
		time = 2,
		delta_time = 2,
		old_state = "clear",
		new_state = "startMissed",
	}})
	ctx.clear_events()

	ctx.logic_info.time = 13
	ctx.logic_note:update()

	t:tdeq(ctx.events, {{
		index = 0,
		type = "hold",
		time = 12,
		delta_time = 2,
		old_state = "startMissed",
		new_state = "endMissed",
	}})
end

---@param t testing.T
function test.perfect_hold(t)
	local ctx = new_test_ctx()

	ctx.logic_info.time = 0
	ctx.logic_note:update()
	ctx.logic_note:input(true)

	t:tdeq(ctx.events, {{
		index = 0,
		type = "hold",
		time = 0,
		delta_time = 0,
		old_state = "clear",
		new_state = "startPassedPressed",
	}})
	ctx.clear_events()

	ctx.logic_info.time = 10
	ctx.logic_note:update()
	ctx.logic_note:input(false)

	t:tdeq(ctx.events, {{
		index = 0,
		type = "hold",
		time = 10,
		delta_time = 0,
		old_state = "startPassedPressed",
		new_state = "endPassed",
	}})
end

---@param t testing.T
function test.early_release(t)
	local ctx = new_test_ctx()

	ctx.logic_info.time = 0.5
	ctx.logic_note:update()
	ctx.logic_note:input(true)

	t:tdeq(ctx.events, {{
		index = 0,
		type = "hold",
		time = 0.5,
		delta_time = 0.5,
		old_state = "clear",
		new_state = "startPassedPressed",
	}})
	ctx.clear_events()

	ctx.logic_info.time = 5
	ctx.logic_note:update()
	ctx.logic_note:input(false)

	t:tdeq(ctx.events, {{
		index = 0,
		type = "hold",
		time = 5,
		delta_time = -5,
		old_state = "startPassedPressed",
		new_state = "startMissed",
	}})
	ctx.clear_events()

	ctx.logic_note:input(true)

	t:tdeq(ctx.events, {{
		index = 0,
		type = "hold",
		time = 5,
		delta_time = -5,
		old_state = "startMissed",
		new_state = "startMissedPressed",
	}})
	ctx.clear_events()

	ctx.logic_note:input(false)

	t:tdeq(ctx.events, {{
		index = 0,
		type = "hold",
		time = 5,
		delta_time = -5,
		old_state = "startMissedPressed",
		new_state = "startMissed",
	}})
	ctx.clear_events()
end

---@param t testing.T
function test.late_press(t)
	local ctx = new_test_ctx()

	ctx.logic_info.time = 1.5
	ctx.logic_note:update()
	ctx.logic_note:input(true)

	t:tdeq(ctx.events, {{
		index = 0,
		type = "hold",
		time = 1.5,
		delta_time = 1.5,
		old_state = "clear",
		new_state = "startMissedPressed",
	}})
	ctx.clear_events()

	ctx.logic_info.time = 10
	ctx.logic_note:update()
	ctx.logic_note:input(false)

	t:tdeq(ctx.events, {{
		index = 0,
		type = "hold",
		time = 10,
		delta_time = 0,
		old_state = "startMissedPressed",
		new_state = "endMissedPassed",
	}})
end

---@param t testing.T
function test.too_late_press(t)
	local ctx = new_test_ctx()

	ctx.logic_info.time = 5
	ctx.logic_note:update()

	t:tdeq(ctx.events, {{
		index = 0,
		type = "hold",
		time = 2,
		delta_time = 2,
		old_state = "clear",
		new_state = "startMissed",
	}})
	ctx.clear_events()

	ctx.logic_note:input(true)

	t:tdeq(ctx.events, {{
		index = 0,
		type = "hold",
		time = 5,
		delta_time = -5,
		old_state = "startMissed",
		new_state = "startMissedPressed",
	}})
	ctx.clear_events()

	ctx.logic_info.time = 10
	ctx.logic_note:update()
	ctx.logic_note:input(false)

	t:tdeq(ctx.events, {{
		index = 0,
		type = "hold",
		time = 10,
		delta_time = 0,
		old_state = "startMissedPressed",
		new_state = "endMissedPassed",
	}})
end

return test
