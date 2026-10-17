local TimeEngine = require("rizu.engine.time.TimeEngine")

local test = {}

---@param t testing.T
function test.set_global_time(t)
	local ti = TimeEngine()
	ti:setGlobalTime(0)
	ti:play()

	t:eq(ti.time, 0)

	ti:setGlobalTime(1)
	t:eq(ti.time, 1)

	ti:setGlobalTime(2)
	t:eq(ti.time, 2)
end

---@param t testing.T
function test.set_global_time_adjusts_time(t)
	local ti = TimeEngine()
	ti:setGlobalTime(0)
	ti:setAdjustFactor(0.5)
	ti:setAdjustFunction(function() return 10 end)
	ti:play()

	t:eq(ti.time, 0)
	t:eq(ti:getOffsync(), -10)

	ti:setGlobalTime(1)
	t:eq(ti.time, 5)
end

---@param t testing.T
function test.set_global_time_paused(t)
	local ti = TimeEngine()
	ti:setGlobalTime(0)
	ti:setAdjustFactor(1)
	ti:setAdjustFunction(function() return 10 end)

	t:eq(ti.time, 0)

	ti:setGlobalTime(1)
	t:eq(ti.time, 0)
end

---@param t testing.T
function test.set_global_time_adjusts_time(t)
	local ti = TimeEngine()
	ti:setGlobalTime(0)
	ti:setAdjustFactor(1)
	ti:setAdjustFunction(function() return 10 end)
	ti:play()

	t:eq(ti.time, 0)
	t:eq(ti:getOffsync(), -10)

	ti:setGlobalTime(1)
	t:eq(ti.time, 10)
end

---@param t testing.T
function test.set_time_all(t)
	local ti = TimeEngine()
	ti:setGlobalTime(0)
	ti:setAdjustFactor(1)
	ti:setAdjustFunction(function() return 10 end)
	ti:play()

	t:eq(ti.time, 0)

	ti:setTime(2)
	t:eq(ti.time, 2) -- no adjust

	ti:setTime(1)
	t:eq(ti.time, 1) -- can go backwards
end

return test
