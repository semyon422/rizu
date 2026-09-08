local InputEngine = require("rizu.engine.input.InputEngine")
local FakeActiveInputNotes = require("rizu.engine.input.FakeActiveInputNotes")
local TestInputNote = require("rizu.engine.input.notes.TestInputNote")

---@param notes rizu.InputNote[]
---@param time number
local function set_time(notes, time)
	for _, note in ipairs(notes) do
		---@cast note rizu.TestInputNote
		note.current_time = time
	end
end

local test = {}

---@param t testing.T
function test.no_notes(t)
	local notes = {}
	local ie = InputEngine(FakeActiveInputNotes(notes))

	t:has_not_error(ie.receive, ie, {id = 1, pos = 1})
end

---@param t testing.T
function test.match(t)
	local function new_note(match_event)
		local note = TestInputNote()
		note.time = 0
		function note:input(value)
			table.insert(match_event, self)
		end
		function note:match(event)
			return match_event.pos == event.pos
		end
		return note
	end

	local event_1 = {value = true, id = 1, pos = 1}
	local event_2 = {value = true, id = 2, pos = 2}

	local notes = {
		new_note(event_1),
		new_note(event_2),
	}

	local ie = InputEngine(FakeActiveInputNotes(notes))

	set_time(notes, 0)

	ie:receive(event_1)
	t:eq(event_1[1], notes[1])
	t:eq(#event_1, 1)

	ie:receive(event_2)
	t:eq(event_2[1], notes[2])
	t:eq(#event_2, 1)

	ie:receive(event_1)
	t:eq(event_1[2], notes[1])
	t:eq(#event_1, 2)
end

---@param t testing.T
function test.catch(t)
	local function new_note(id, events)
		local note = TestInputNote()
		note.time = 0
		function note:input(value)
			table.insert(events, {id, value})
		end
		function note:match()
			return true
		end
		return note
	end

	local events = {}

	local notes = {
		new_note("a", events),
		new_note("b", events),
	}

	local ie = InputEngine(FakeActiveInputNotes(notes))

	set_time(notes, 0)

	ie:receive({id = 1, value = true})
	ie:receive({id = 2, value = true})
	ie:receive({id = 1, value = true})
	ie:receive({id = 2, value = false})
	ie:receive({id = 1, value = false})

	t:tdeq(events, {
		{"a", true},
		{"b", true},
		{"a", true},
		{"b", false},
		{"a", false},
	})
end

---@param t testing.T
function test.nearest(t)
	local function new_note(time, events)
		local note = TestInputNote()
		---@cast note +{catched: any}
		note.time = time
		function note:input()
			table.insert(events, time)
		end
		function note:match()
			return true
		end
		return note
	end

	local events = {}

	local notes = {
		new_note(0, events),
		new_note(2, events),
	}

	local ie = InputEngine(FakeActiveInputNotes(notes))
	ie.nearest = true

	set_time(notes, 1)

	ie:receive({value = true, id = 1})
	ie:receive({value = false, id = 1})
	t:eq(events[1], 0)

	set_time(notes, 1.001)

	ie:receive({value = true, id = 1})
	ie:receive({value = false, id = 1})
	t:eq(events[3], 2)

	set_time(notes, 0.999)

	ie:receive({value = true, id = 1})
	ie:receive({value = false, id = 1})
	t:eq(events[5], 0)
end

---@param t testing.T
function test.priority(t)
	local function new_note(time, priority, event)
		local note = TestInputNote()
		---@cast note +{catched: any}
		note.time = time
		note.priority = priority
		function note:input()
			table.insert(event, time)
		end
		function note:match()
			return true
		end
		return note
	end

	local event = {value = true, id = 1}

	local notes = {
		new_note(0, 0, event),
		new_note(2, 1, event),
	}

	local ie = InputEngine(FakeActiveInputNotes(notes))

	set_time(notes, 0)

	ie:receive(event)
	t:eq(event[1], 2)
end

---@param t testing.T
function test.nil_value(t)
	local function new_note(events)
		local note = TestInputNote()
		note.time = 0
		function note:input(value)
			table.insert(events, {value})
			return value
		end
		function note:match()
			return true
		end
		return note
	end

	local events = {}

	local notes = {
		new_note(events),
	}

	local ie = InputEngine(FakeActiveInputNotes(notes))

	set_time(notes, 0)

	ie:receive({id = 1, value = nil})
	ie:receive({id = 1, value = true})
	ie:receive({id = 1, value = true})
	ie:receive({id = 1, value = nil})
	ie:receive({id = 1, value = false})

	t:tdeq(events, {
		{true},
		{true},
		{false},
	})

	ie:receive({id = 1, value = false})
	ie:receive({id = 1, value = nil})

	t:tdeq(events, {
		{true},
		{true},
		{false},
	})
end

---@param t testing.T
function test.variable_match(t)
	local function new_note(events)
		local note = TestInputNote()
		note.time = 0
		function note:input(value)
			table.insert(events, {value})
		end
		return note
	end

	local events = {}

	local notes = {
		new_note(events),
	}

	local ie = InputEngine(FakeActiveInputNotes(notes))

	set_time(notes, 0)

	ie:receive({id = 1, pos = true, value = true})
	ie:receive({id = 1, pos = true, value = nil})
	ie:receive({id = 1, pos = false, value = nil})

	t:tdeq(events, {
		{true},
		{false},
	})

	ie:receive({id = 1, pos = true, value = nil})
	ie:receive({id = 1, pos = true, value = nil})
	ie:receive({id = 1, pos = true, value = nil})
	ie:receive({id = 1, pos = false, value = nil})
	ie:receive({id = 1, pos = false, value = nil})
	ie:receive({id = 1, pos = true, value = nil})
	ie:receive({id = 1, pos = true, value = nil})
	ie:receive({id = 1, pos = true, value = false})

	t:tdeq(events, {
		{true},
		{false},
	})
end

--[[
	TODO:
	pause (unmatch / rematch) x (top / bottom)
]]

---@param t testing.T
function test.paused_press_is_applied_on_resume(t)
	---@type boolean[]
	local events = {}
	local note = TestInputNote()
	note.time = 0
	function note:match()
		return true
	end
	function note:input(value)
		table.insert(events, value)
	end
	local ie = InputEngine(FakeActiveInputNotes({note}))
	set_time({note}, 0)

	ie:pause()
	ie:receive({id = 1, value = true})
	t:tdeq(events, {})
	t:eq(ie.event_catches[1], note)
	t:eq(ie.input_pauser.event_values[1], true)

	ie:resume()
	t:tdeq(events, {true})
	ie:receive({id = 1, value = false})
	t:tdeq(events, {true, false})
end

---@param t testing.T
function test.paused_repress_prefers_held_note_over_next_note(t)
	---@type boolean[]
	local events = {}
	local held = TestInputNote()
	held.time = 0
	held.priority = -1
	function held:match() return true end
	function held:input(value)
		table.insert(events, value)
	end
	local next_note = TestInputNote()
	next_note.time = 1
	next_note.priority = 0
	function next_note:match() return true end
	local notes = {held}
	local ie = InputEngine(FakeActiveInputNotes(notes))
	set_time({held, next_note}, 0)
	ie:receive({id = 1, value = true})
	notes[2] = next_note
	ie:pause()
	ie:receive({id = 1, value = false})
	ie:receive({id = 2, value = true})
	t:eq(ie.event_catches[2], held)
	t:tdeq(events, {true})
	ie:resume()
	t:tdeq(events, {true})
	ie:receive({id = 2, value = false})
	t:tdeq(events, {true, false})
end

return test
