local Spinner = require("rizu.gameplay.aim.Spinner")
local test = {}

---@param t testing.T
function test.both_directions_and_wraparound(t)
	for _, direction in ipairs({-1, 1}) do
		local spinner = Spinner({time = 1, end_time = 3}, 5)
		for i = 0, 240 do
			local angle = direction * i / 120 * 4 * 2 * math.pi
			spinner:receive(1 + i / 120, 256 + math.cos(angle) * 100, 192 + math.sin(angle) * 100, true, false)
		end
		t:aeq(spinner:getTurns(), 8, 1e-9)
		t:eq(spinner.required_turns, 4.5)
	end
end

---@param t testing.T
function test.pause_release_deadzone_and_same_time_do_not_add_rotation(t)
	local spinner = Spinner({time = 1, end_time = 4}, 5)
	spinner:receive(0, 356, 192, true, false)
	spinner:receive(1, 256, 292, true, false)
	t:eq(spinner:getTurns(), 0)
	spinner:receive(1, 156, 192, true, false)
	t:eq(spinner:getTurns(), 0)
	spinner:receive(1.1, 256, 192, true, false)
	spinner:receive(1.2, 356, 192, true, false)
	t:eq(spinner:getTurns(), 0)
	spinner:receive(1.3, 256, 292, true, true)
	spinner:receive(1.4, 156, 192, true, false)
	t:eq(spinner:getTurns(), 0)
	spinner:receive(1.5, 256, 92, false, false)
	spinner:receive(1.6, 356, 192, true, false)
	t:eq(spinner:getTurns(), 0)
	spinner:receive(5, 256, 292, true, false)
	t:eq(spinner:getTurns(), 0)
end

---@param t testing.T
function test.reversals_cancel_and_speed_is_bounded(t)
	local spinner = Spinner({time = 0, end_time = 10}, 0)
	spinner:receive(0, 356, 192, true, false)
	spinner:receive(0.1, 256, 292, true, false)
	spinner:receive(0.2, 356, 192, true, false)
	t:aeq(spinner:getTurns(), 0, 1e-9)
	spinner:receive(0.201, 156, 192, true, false)
	t:aeq(spinner:getTurns(), 0.008, 1e-9)
end

return test
