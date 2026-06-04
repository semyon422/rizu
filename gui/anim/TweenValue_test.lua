local TweenValue = require("gui.anim.TweenValue")

local test = {}

---@param t testing.T
function test.uses_duration_tweening(t)
	local value = TweenValue({
		value = 10,
		duration = 0.5,
	})

	value:set(20)
	t:eq(value:update(0.25), 15)
	t:eq(value:update(0.25), 20)
	t:eq(value:get(), 20)
	t:eq(value.target, 20)
	t:eq(value:isAnimating(), false)
end

---@param t testing.T
function test.uses_speed_to_resolve_duration(t)
	local value = TweenValue({
		value = 0,
		speed = 4,
	})

	value:set(8)
	t:eq(value:update(1), 4)
	t:eq(value:update(1), 8)
end

---@param t testing.T
function test.zero_duration_snaps_immediately(t)
	local value = TweenValue({
		value = 1,
		duration = 0,
	})

	value:set(3)
	t:eq(value:get(), 3)
	t:eq(value.target, 3)
	t:eq(value.velocity, 0)
end

---@param t testing.T
function test.rejects_non_tween_mode(t)
	t:has_error(TweenValue, {
		mode = "spring",
	})
end

return test
