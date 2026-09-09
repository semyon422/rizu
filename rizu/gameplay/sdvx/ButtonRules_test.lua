local ButtonRules = require("rizu.gameplay.sdvx.ButtonRules")
local Input = require("rizu.gameplay.sdvx.Input")
local ReplayFrames = require("rizu.engine.replay.ReplayFrames")
local test = {}

---@return chart.ksm.SdvxButton[]
local function objects()
	return {
		{time = 1, end_time = 1, lane = 1, kind = "chip"},
		{time = 1, end_time = 2, lane = 5, kind = "hold"},
		{time = 1.5, end_time = 1.5, lane = 3, kind = "chip"},
	}
end

---@param t testing.T
function test.chip_hold_overlap_release_at_tail(t)
	local rules = ButtonRules(objects())
	rules:receive(1, true, 1)
	rules:receive(5, true, 1)
	rules:receive(3, true, 1.5)
	rules:receive(5, false, 2)
	rules:update(3)
	t:eq(rules.hits, 3)
	t:eq(rules.misses, 0)
end

---@param t testing.T
function test.hold_release_and_repress_does_not_erase_loss(t)
	local rules = ButtonRules(objects())
	rules:receive(5, true, 1)
	rules:receive(5, false, 1.5, true)
	rules:receive(5, true, 1.5, true)
	rules:update(3)
	t:eq(rules.states[2].result, "miss")
end

---@param t testing.T
function test.paused_key_repeat_does_not_hit(t)
	local rules = ButtonRules(objects())
	rules:receive(1, true, 1, true)
	rules:receive(1, true, 1)
	t:eq(rules.hits, 0)
	rules:receive(1, false, 1)
	rules:receive(1, true, 1)
	t:eq(rules.hits, 1)
end

---@param t testing.T
function test.expiry_events_have_stable_order(t)
	local a, b = ButtonRules(objects()), ButtonRules(objects())
	a:receive(5, true, 1); b:receive(5, true, 1)
	a:update(3)
	for time = 1.01, 3, 0.01 do b:update(time) end
	b:update(3)
	t:tdeq(a.events, b.events)
end

---@param t testing.T
function test.keys_and_wrapped_turns_survive_binary_replay(t)
	local input = Input()
	local frames = {}
	for id, key in ipairs({"d", "f", "j", "k", "c", "m", "w", "e", "o", "p"}) do
		local event = input:transform({name = "keypressed", key})
		t:eq(event.id, id)
		frames[#frames + 1] = {time = id, event = event}
	end
	input:axis(1, 0.99)
	local event = input:axis(1, -0.99)
	t:eq(event.id, 11)
	t:aeq(event.pos[1], 0.02, 1e-9)
	frames[#frames + 1] = {time = 11, event = event}
	frames[#frames + 1] = {time = 12, event = input:axis(2, 0.1, true)}
	t:tdeq(ReplayFrames.decode(ReplayFrames.encode(frames)), frames)
end

return test
