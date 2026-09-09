local Rules = require("rizu.gameplay.taiko.Rules")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")
local test = {}

---@return chart.osu.TaikoChart
local function chart()
	return {overall_difficulty = 5, objects = {
		{time = 1, end_time = 1, kind = "note", color = "don", big = false, target = 1, sounds = {}},
		{time = 2, end_time = 2, kind = "note", color = "kat", big = true, target = 1, sounds = {}},
		{time = 3, end_time = 4, kind = "roll", color = "don", big = false, target = 4, sounds = {}},
		{time = 5, end_time = 6, kind = "spinner", color = "don", big = false, target = 5, sounds = {}},
	}}
end

---@param rules rizu.taiko.Rules
---@param id integer
---@param time number
local function tap(rules, id, time)
	rules:receive(VirtualInputEvent(id, true, 1), time)
	rules:receive(VirtualInputEvent(id, false, 1), time)
end

---@param t testing.T
function test.wrong_color_and_two_distinct_hands(t)
	local rules = Rules(chart())
	tap(rules, 3, 1)
	t:eq(rules.misses, 1)
	rules:receive(VirtualInputEvent(3, true, 1), 2)
	rules:update(2.01)
	rules:receive(VirtualInputEvent(3, true, 1), 2.015)
	t:eq(rules.doubles, 0)
	rules:receive(VirtualInputEvent(4, true, 1), 2.025)
	t:eq(rules.doubles, 1)
	t:eq(rules.hits, 1)
end

---@param t testing.T
function test.late_second_hand_and_released_first_hand_are_single(t)
	for _, released in ipairs({true, false}) do
		local rules = Rules(chart())
		rules:receive(VirtualInputEvent(3, true, 1), 2)
		if released then rules:receive(VirtualInputEvent(3, false, 1), 2.01) end
		rules:receive(VirtualInputEvent(4, true, 1), released and 2.02 or 2.031)
		rules:update(2.1)
		t:eq(rules.singles, 1)
		t:eq(rules.doubles, 0)
	end
end

---@param t testing.T
function test.roll_needs_edges_and_spinner_needs_alternation(t)
	local rules = Rules(chart())
	rules:receive(VirtualInputEvent(1, true, 1), 3)
	rules:receive(VirtualInputEvent(1, true, 1), 3.1)
	t:eq(rules.states[3].count, 1)
	rules:receive(VirtualInputEvent(1, false, 1), 3.1)
	for j = 1, 3 do tap(rules, 1, 3.1 + j * 0.1) end
	t:eq(rules.states[3].result, "hit")
	tap(rules, 1, 5)
	tap(rules, 2, 5.1)
	t:eq(rules.states[4].count, 1)
	for j = 1, 4 do tap(rules, j % 2 == 1 and 3 or 1, 5.1 + j * 0.1) end
	t:eq(rules.states[4].result, "hit")
end

---@param t testing.T
function test.paused_press_never_hits_on_resume(t)
	local rules = Rules(chart())
	rules:receive(VirtualInputEvent(1, true, 2), 1)
	rules:receive(VirtualInputEvent(1, true, 1), 1)
	t:eq(rules.hits, 0)
	rules:receive(VirtualInputEvent(1, false, 1), 1)
	tap(rules, 1, 1)
	t:eq(rules.hits, 1)
end

---@param t testing.T
function test.autoplay_is_identical_across_update_partitions(t)
	---@type rizu.taiko.Judgement[]?
	local expected
	for _, step in ipairs({10, 1 / 30, 1 / 144, 0.017}) do
		local rules = Rules(chart())
		local time = 0
		for _, frame in ipairs(Rules.autoplay(chart())) do
			while time + step < frame.time do time = time + step; rules:update(time) end
			rules:receive(frame.event, frame.time)
			time = frame.time
		end
		rules:update(7)
		t:eq(rules.hits, 4)
		t:eq(rules.misses, 0)
		t:eq(rules.doubles, 1)
		if expected then t:tdeq(rules.events, expected) else expected = rules.events end
	end
end

return test
