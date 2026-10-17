local InputPauser = require("rizu.engine.input.InputPauser")
local TestInputNote = require("rizu.engine.input.notes.TestInputNote")

local test = {}

local function new_note(events)
	local note = TestInputNote()
	function note:input(value)
		table.insert(events, value)
	end
	return note
end

---@param t testing.T
function test.keep_pressed_id_changed(t)
	local events = {}
	local note = new_note(events)

	local ip = InputPauser()

	ip:receive(1, true)
	ip:pause({[note] = 1})
	ip:receive(1, false)
	ip:receive(2, true)

	ip:resume({[note] = 2})
	t:tdeq(events, {})

	t:tdeq(ip.event_values, {[2] = true})
	t:tdeq(ip.paused_notes, {})
end

---@param t testing.T
function test.press_on_resume(t)
	local events = {}
	local note = new_note(events)

	local ip = InputPauser()

	ip:pause({})
	ip:receive(1, true)
	ip:resume({[note] = 1})
	t:tdeq(events, {true})

	t:tdeq(ip.event_values, {[1] = true})
	t:tdeq(ip.paused_notes, {})
end

---@param t testing.T
function test.release_on_resume(t)
	local events = {}
	local note = new_note(events)

	local ip = InputPauser()

	ip:receive(1, true)
	ip:pause({[note] = 1})
	ip:receive(1, false)
	ip:resume({})
	t:tdeq(events, {false})

	t:tdeq(ip.event_values, {})
	t:tdeq(ip.paused_notes, {})
end

return test
