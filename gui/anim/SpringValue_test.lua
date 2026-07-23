local SpringValue = require("gui.anim.SpringValue")

local test = {}

---@param t testing.T
function test.spring_moves_towards_target(t)
	local value = SpringValue({
		value = 0,
		stiffness = 240,
		damping = 28,
		max_step = 1 / 240,
	})

	value:set(1)
	local current = value:update(0.05)
	t:assert(current > 0)
	t:assert(current < 1)
	t:assert(value:isAnimating())
end

---@param t testing.T
function test.spring_settles_to_target(t)
	local value = SpringValue({
		value = 0,
		target = 1,
		stiffness = 240,
		damping = 28,
		epsilon = 0.001,
		max_step = 1 / 240,
	})

	for _ = 1, 240 do
		value:update(1 / 60)
	end

	t:eq(value:get(), 1)
	t:eq(value.target, 1)
	t:eq(value.velocity, 0)
	t:eq(value:isAnimating(), false)
end

---@param t testing.T
function test.snap_resets_velocity(t)
	local value = SpringValue({
		value = 0,
		velocity = 5,
	})

	value:snap(3)
	t:eq(value:get(), 3)
	t:eq(value.target, 3)
	t:eq(value.velocity, 0)
end

return test
