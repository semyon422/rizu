local Laser = require("rizu.gameplay.sdvx.Laser")
local Knob = require("rizu.gameplay.sdvx.Knob")
local test = {}

---@return chart.ksm.SdvxLaser
local function chain()
	return {lane = 1, extended = false, segments = {
		{time = 0, end_time = 1, beat = 0, end_beat = 2, from = 0, to = 1, slam = false},
		{time = 1, end_time = 2, beat = 2, end_beat = 4, from = 1, to = 1, slam = false},
		{time = 2, end_time = 3, beat = 4, end_beat = 6, from = 1, to = 0, slam = false},
	}}
end

---@param t testing.T
function test.direction_tracking_straight_lock_and_reversal(t)
	local laser = Laser(chain())
	laser:setDirection(1, 0)
	laser:setDirection(0, 1)
	laser:update(2)
	t:eq(laser.position, 1)
	t:eq(laser.captured, true)
	laser:setDirection(-1, 2)
	laser:update(3.1)
	t:eq(laser.position, 0)
	for _, tick in ipairs(laser.ticks) do t:eq(tick.hit, true) end
end

---@param t testing.T
function test.loss_and_reacquisition(t)
	local laser = Laser(chain())
	laser:update(0.5)
	t:eq(laser.captured, false)
	laser:setDirection(1, 0.5)
	laser:update(1.2)
	t:eq(laser.captured, true)
	t:eq(laser.position, 1)
end

---@param t testing.T
function test.fixed_checkpoints_ignore_render_partitions(t)
	local a, b = Laser(chain()), Laser(chain())
	a:setDirection(1, 0); b:setDirection(1, 0)
	a:update(1.9)
	for time = 0.007, 1.9, 0.007 do b:update(time) end
	b:update(1.9)
	t:tdeq(a.ticks, b.ticks)
	t:eq(a.position, b.position)
end

---@param t testing.T
function test.slam_requires_a_timely_turn_and_paused_turn_is_ignored(t)
	local c = chain()
	c.segments = {{time = 1, end_time = 1, beat = 2, end_beat = 2, from = 0, to = 1, slam = true}}
	local laser = Laser(c)
	laser:setDirection(1, 0)
	laser:turn(0.1, 1, true)
	laser:turn(-0.1, 1)
	t:eq(laser.slams[1], nil)
	laser:turn(0.1, 1.02)
	t:eq(laser.slams[1], "hit")
	t:eq(laser.position, 1)
	local missed = Laser(c)
	missed:setDirection(1, 0)
	missed:update(1.2)
	t:eq(missed.slams[1], "miss")
end

---@param t testing.T
function test.wrapped_encoder_baseline_pause_inversion_and_deadzone(t)
	local knob = Knob(2, false, 0.001)
	t:eq(knob:sample(0.99), 0)
	t:aeq(knob:sample(-0.99), 0.04, 1e-9)
	t:eq(knob:sample(0.3, true), 0)
	t:aeq(knob:sample(0.4), 0.2, 1e-9)
	knob:reset()
	t:eq(knob:sample(0.9), 0)
	t:eq(knob:sample(0.9001), 0)
	local inverted = Knob(1, true, 0)
	inverted:sample(0)
	t:eq(inverted:sample(0.5), -0.5)
end

return test
