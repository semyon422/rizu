local SdvxChart = require("chart.format.ksm.SdvxChart")
local Rules = require("rizu.gameplay.sdvx.Rules")
local Input = require("rizu.gameplay.sdvx.Input")
local ReplayFrames = require("rizu.engine.replay.ReplayFrames")
local test = {}

---@param t testing.T
function test.dual_lasers_and_buttons_replay_across_update_partitions(t)
	local chart = SdvxChart([[t=120
--
2222|11|0o
2222|11|::
2222|11|o0
0000|00|--
--
]])
	local input = Input()
	local frames = {}
	for _, key in ipairs({"d", "f", "j", "k", "c", "m", "e", "o"}) do
		frames[#frames + 1] = {time = 0, event = input:transform({name = "keypressed", key})}
	end
	for _, key in ipairs({"d", "f", "j", "k", "c", "m", "e", "o"}) do
		frames[#frames + 1] = {time = 1.5, event = input:transform({name = "keyreleased", key})}
	end
	frames = ReplayFrames.decode(ReplayFrames.encode(frames))
	---@type rizu.sdvx.Rules?
	local expected
	for _, step in ipairs({4, 1 / 30, 1 / 144, 0.017}) do
		local rules = Rules(chart)
		local time = 0
		for _, frame in ipairs(frames) do
			while time + step < frame.time do time = time + step; rules:update(time) end
			rules:receive(frame.event, frame.time)
			time = frame.time
		end
		rules:update(3)
		t:eq(rules.button_rules.hits, 6)
		for _, laser in ipairs(rules.lasers) do
			for _, tick in ipairs(laser.ticks) do t:eq(tick.hit, true) end
		end
		if expected then
			t:tdeq(rules.button_rules.events, expected.button_rules.events)
			for i, laser in ipairs(rules.lasers) do t:tdeq(laser.ticks, expected.lasers[i].ticks) end
		else expected = rules end
	end
end

---@param t testing.T
function test.autoplay_uses_keyboard_edges_for_slam_and_both_lasers(t)
	local rows = {"1000|20|0o", "0000|00|o0", "0000|00|::", "0000|00|::", "0000|00|0o", "0000|00|--"}
	for _ = 7, 32 do rows[#rows + 1] = "0000|00|--" end
	local chart = SdvxChart("t=120\n--\n" .. table.concat(rows, "\n"))
	local rules = Rules(chart)
	local previous = -math.huge
	for _, frame in ipairs(Rules.autoplay(chart)) do
		t:assert(frame.time >= previous)
		t:eq(frame.event.pos, nil)
		previous = frame.time
		rules:receive(frame.event, frame.time)
	end
	rules:update(3)
	t:eq(rules.button_rules.hits, 2)
	for _, laser in ipairs(rules.lasers) do
		t:eq(laser.slams[1], "hit")
		for _, tick in ipairs(laser.ticks) do t:eq(tick.hit, true) end
	end
end

return test
