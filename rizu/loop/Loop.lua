local Observable = require("Observable")
local thread = require("thread")
local delay = require("delay")
local asynckey = require("asynckey")
local flux = require("flux")
local reqprof = require("reqprof")
local table_util = require("table_util")

local LoopEvents = require("rizu.loop.LoopEvents")
local LoopLimiter = require("rizu.loop.LoopLimiter")
local LoopQuitting = require("rizu.loop.LoopQuitting")
local LoopGraphics = require("rizu.loop.LoopGraphics")
local SleepFunctionFactory = require("rizu.loop.sleep.SleepFunctionFactory")

---@class rizu.Loop: util.Observable
---@operator call: rizu.Loop
local Loop = Observable + {}

function Loop:init()
	self.limiter = LoopLimiter(self)
	self.events = LoopEvents(self)
	self.quitter = LoopQuitting(self)
	self.graphics = LoopGraphics(self)
	self.sleep_function_factory = SleepFunctionFactory()

	self.time = 0
	self.dt = 0
	self.start_time = 0
	self.stats = {}
	self.dt_limit = 1 / 10
	self.timings = {
		dt = 0,
		event = 0,
		update = 0,
		draw = 0,
		present = 0,
		gc = 0,
		sleep = 0,
		busy = 0,
	}
	self.timings_next = table_util.copy(self.timings)

	self.mem_count = collectgarbage("count")
	self.mem_delta = 0

	collectgarbage("setpause", 100)
	collectgarbage("setstepmul", 200)
	self.gc_step_size = 2

	self.ema_dt = 0
	self.ema_jitter = 0
	self.prev_frame_dt = 0

	self.quitting = false
	self.quit_code = 0

	self.frame_started = {name = "framestarted"}

	love.quit = function(...)
		print("Quitting")
		self.quitting = true
		return true
	end
end

-- Setters for configuration
function Loop:setFpsLimit(limit) self.limiter.fps_limit = limit end
function Loop:setUnlimitedFps(enabled) self.limiter.unlimited_fps = enabled end
function Loop:setBusyLoopRatio(ratio) self.limiter.busy_loop_ratio = ratio end
function Loop:setAsynckey(enabled) self.events.asynckey = enabled end
function Loop:setGcStepSize(size) self.gc_step_size = size end
function Loop:setDwmFlush(enabled) self.graphics.dwm_flush = enabled end
function Loop:setSleepFunction(_type)
	self.limiter.sleep_function = self.sleep_function_factory:get(_type)
end

---@return number|string?
function Loop:quittingLoop()
	return self.quitter:update()
end

function Loop:_update(dt)
	thread.update()
	delay.update()
	flux.update(math.min(dt, self.dt_limit))
	self.events:dispatchEvent("update", dt)
end

---@return function
function Loop:run()
	love.math.setRandomSeed(os.time())
	math.randomseed(os.time())
	love.timer.step()

	local get_time = love.timer.getTime

	local start_time = get_time()
	self.limiter:reset(start_time)
	self.prev_time = start_time
	self.time = start_time
	self.start_time = start_time
	self.dt = 0

	local frame_start_time = get_time()
	local time_1, time_2 = frame_start_time, frame_start_time

	local function measure_time()
		time_1, time_2 = get_time(), time_1
		return time_1 - time_2
	end

	local t = self.timings_next

	return function()
		if self.quitting then
			local res = self:quittingLoop()
			local _time = get_time()
			t.dt = _time - frame_start_time
			frame_start_time = _time
			return res
		end

		reqprof.start()

		if self.events.asynckey and asynckey.start then
			asynckey.start()
		end

		love.timer.step()
		local time = get_time()

		self.dt = time - self.time
		self.prev_time, self.time = self.time, time

		-- Metrics calculation
		local alpha = 0.05
		self.ema_dt = self.ema_dt == 0 and self.dt or (self.ema_dt * (1 - alpha) + self.dt * alpha)
		self.jitter = math.abs(self.dt - self.prev_frame_dt)
		self.ema_jitter = self.ema_jitter == 0 and self.jitter or (self.ema_jitter * (1 - alpha) + self.jitter * alpha)
		self.prev_frame_dt = self.dt

		local current_mem = collectgarbage("count")
		self.mem_delta = current_mem - self.mem_count
		self.mem_count = current_mem

		self.frame_started.time = self.time
		self.frame_started.dt = self.dt
		self:send(self.frame_started)

		local quit_res = self.events:pollEvents(time)
		t.event = measure_time()
		if quit_res then return quit_res end

		self:_update(self.dt)
		t.update = measure_time()

		self.graphics:draw()
		t.draw = measure_time()

		self.graphics:present()
		t.present = measure_time()

		if self.gc_step_size > 0 then
			collectgarbage("step", self.gc_step_size)
		end
		t.gc = measure_time()

		local target_time, to_sleep = self.limiter:limit(time_1)

		self.limiter:sleep(to_sleep)
		t.sleep = measure_time()

		self.limiter:busyWait(target_time)
		t.busy = measure_time()

		t.dt = time_1 - frame_start_time
		frame_start_time = time_1

		self.timings, self.timings_next = self.timings_next, self.timings
		t = self.timings_next
	end
end

return Loop
