local LocalTimer = require("rizu.engine.time.LocalTimer")

local test = {}

---@param t testing.T
function test.not_init(t)
	local timer = LocalTimer()

	local err = "timer not initialized"
	t:eq(t:has_error(timer.transform, timer, 0), err)
	t:eq(t:has_error(timer.play, timer), err)

	timer:pause()
	timer:setRate(2)
	timer:setTime(10)

	t:eq(timer:getTime(), 10)

	timer:setTime(5)

	timer:setGlobalTime(10)
	t:eq(timer:getTime(), 10)
	t:eq(timer:getTime(true), 5)

	timer:play()
	t:eq(timer:getTime(), 10)
	t:eq(timer:getTime(true), 5)

	timer:setGlobalTime(12.5)
	t:eq(timer:getTime(), 10)
	t:eq(timer:getTime(true), 10)

	timer:setGlobalTime(15)
	t:eq(timer:getTime(), 15)
	t:eq(timer:getTime(true), 15)
end

---@param t testing.T
function test.changing_time(t)
	local timer = LocalTimer()

	timer:setGlobalTime(0)

	timer:play()
	t:eq(timer:getTime(), 0)

	timer:setGlobalTime(1)
	t:eq(timer:getTime(), 1)

	t:eq(timer:transform(0), 0)
	t:eq(timer:transform(1), 1)
	t:eq(timer:transform(2), 2)
end

---@param t testing.T
function test.changing_time_with_rate(t)
	local timer = LocalTimer()

	timer:setGlobalTime(0)

	timer:play()
	timer:setRate(2)
	t:eq(timer:getTime(), 0)

	timer:setGlobalTime(1)
	t:eq(timer:getTime(), 2)

	timer:setGlobalTime(2)
	t:eq(timer:getTime(), 4)

	t:eq(timer:transform(0), 0)
	t:eq(timer:transform(1), 2)
	t:eq(timer:transform(2), 4)
end

---@param t testing.T
function test.set_time(t)
	local timer = LocalTimer()

	timer:setGlobalTime(0)

	timer:play()
	t:eq(timer:getTime(), 0)

	timer:setTime(1)
	t:eq(timer:getTime(), 1)

	t:eq(timer:transform(0), 1)
	t:eq(timer:transform(1), 2)
	t:eq(timer:transform(2), 3)
end

---@param t testing.T
function test.set_time_with_rate(t)
	local timer = LocalTimer()

	timer:setGlobalTime(0)

	timer:play()
	t:eq(timer:getTime(), 0)

	timer:setTime(1)
	timer:setRate(2)
	t:eq(timer:getTime(), 1)

	t:eq(timer:transform(0), 1)
	t:eq(timer:transform(1), 3)
	t:eq(timer:transform(2), 5)
end

---@param t testing.T
function test.set_rate(t)
	local timer = LocalTimer()

	timer:setGlobalTime(0)

	timer:play()

	timer:setGlobalTime(1)
	t:eq(timer:getTime(), 1)

	timer:setRate(2)
	t:eq(timer:getTime(), 1)
end

---@param t testing.T
function test.play_pause(t)
	local timer = LocalTimer()

	timer:setGlobalTime(0)

	timer:play()
	t:eq(timer:getTime(), 0)

	timer:setGlobalTime(1)
	t:eq(timer:getTime(), 1)
	t:eq(timer:transform(1), 1)

	--

	timer:pause()
	t:eq(timer:getTime(), 1)
	t:eq(timer:transform(1), 1)

	--

	timer:setGlobalTime(2)
	t:eq(timer:getTime(), 1)
	t:eq(timer:transform(1), 0)

	--

	timer:play()
	timer:setGlobalTime(3)
	t:eq(timer:getTime(), 2)

	t:eq(timer:transform(0), -1)
	t:eq(timer:transform(1), 0)
	t:eq(timer:transform(2), 1)
end

---@param t testing.T
function test.monotonic(t)
	local timer = LocalTimer()

	timer:setGlobalTime(0)

	timer:play()
	t:eq(timer:getTime(), 0)

	timer:setGlobalTime(1)
	t:eq(timer:getTime(), 1)

	timer:setTime(0.5)
	t:eq(timer:getTime(), 1)

	timer:setGlobalTime(1.5)
	t:eq(timer:getTime(), 1)

	timer:setGlobalTime(1.6)
	t:eq(timer:getTime(), 1.1)

	timer:setTime(0.5, true)
	t:eq(timer:getTime(), 0.5)
end

return test
