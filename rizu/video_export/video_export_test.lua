local FfmpegLocator = require("rizu.video_export.FfmpegLocator")
local FfmpegEncoder = require("rizu.video_export.FfmpegEncoder")
local VideoExportJob = require("rizu.video_export.VideoExportJob")

local test = {}

---@param t testing.T
function test.locator_runs_version_and_caches(t)
	local calls, status = {}, 0
	local locator = FfmpegLocator(function(command)
		table.insert(calls, command)
		return status
	end)
	t:eq(locator:isAvailable(), true)
	t:eq(locator:isAvailable(), true)
	t:eq(#calls, 1)
	t:assert(calls[1]:find("-version", 1, true))

	status = 127
	locator:setPath("/opt/ff mpeg")
	t:eq(locator:isAvailable(), false)
	t:assert(calls[2]:find('"/opt/ff mpeg"', 1, true))
end

local function fake_encoder(written, sizes)
	local pipe = {
		write = function(_, bytes) table.insert(written, bytes) return true end,
		close = function() end,
	}
	local commands = {}
	local encoder = FfmpegEncoder({path = "ffmpeg"}, function(command, mode)
		table.insert(commands, {command, mode})
		return pipe
	end, function() return sizes.output end, function(path) table.insert(sizes, path) end)
	return encoder, commands
end

---@param t testing.T
function test.encoder_opens_binary_pipe(t)
	local encoder, commands = fake_encoder({}, {output = 10})
	t:eq(encoder:open({width = 4, height = 2, fps = 30, format = "webp", path = "out.webp"}), true)
	t:eq(commands[1][2], require("jit").os == "Windows" and "wb" or "w")
	t:assert(commands[1][1]:find("-s 4x2", 1, true))
	t:assert(commands[1][1]:find("libwebp_anim", 1, true))
	t:eq(encoder:open({width = 4, height = 2, fps = 30, format = "nope", path = "x"}), false)
end

---@param t testing.T
function test.encoder_close_requires_output(t)
	local encoder = fake_encoder({}, {output = 0})
	encoder:open({width = 1, height = 1, fps = 1, format = "webp", path = "out.webp"})
	t:eq(encoder:close(), false)
end

local function fake_graphics(calls)
	local canvas = {
		release = function() table.insert(calls, "canvas_release") end,
	}
	return {
		newCanvas = function() return canvas end,
		readbackTexture = function() return {getString = function() return "frame" end, release = function() end} end,
		push = function() table.insert(calls, "push") end,
		pop = function() table.insert(calls, "pop") end,
		setCanvas = function() end,
		clear = function() end,
		origin = function() end,
	}
end

---@param t testing.T
function test.job_renders_all_frames_then_finishes(t)
	local written, sizes, gcalls = {}, {output = 10}, {}
	local encoder = fake_encoder(written, sizes)
	local times = {}
	local job = VideoExportJob(encoder, fake_graphics(gcalls), function() return 0 end)
	t:eq(job:start({
		width = 2, height = 2, fps = 10, duration = 0.5, start_time = 1, path = "o.webp", format = "webp",
		draw = function(time) table.insert(times, time) end,
	}), true)
	t:eq(job.frames, 5)
	while job.state == "running" do job:step(1) end
	t:eq(job.state, "finishing")
	t:eq(job:getProgress(), 1)
	job:step()
	t:eq(job.state, "done")
	t:eq(#written, 5)
	t:eq(#times, 5)
	t:eq(math.abs(times[1] - 1) < 1e-9, true)
	t:eq(math.abs(times[5] - 1.4) < 1e-9, true)
end

---@param t testing.T
function test.job_step_respects_budget(t)
	local now = 0
	local job = VideoExportJob(fake_encoder({}, {output = 1}), fake_graphics({}), function()
		now = now + 1
		return now
	end)
	job:start({width = 1, height = 1, fps = 10, duration = 10, path = "o", format = "webp", draw = function() end})
	job:step(2.5)
	t:assert(job.frame >= 1 and job.frame < 100)
	t:eq(job.state, "running")
end

---@param t testing.T
function test.job_fails_when_draw_errors_and_restores_graphics(t)
	local sizes, gcalls = {output = 1}, {}
	local job = VideoExportJob(fake_encoder({}, sizes), fake_graphics(gcalls), function() return 0 end)
	job:start({width = 1, height = 1, fps = 10, duration = 1, path = "o.webp", format = "webp",
		draw = function() error("boom") end})
	job:step()
	t:eq(job.state, "failed")
	t:assert(job.error:find("boom", 1, true))
	t:eq(gcalls[#gcalls - 1], "pop")
	t:eq(sizes[1], "o.webp") -- unfinished output removed
end

---@param t testing.T
function test.job_cancel_removes_output(t)
	local sizes = {output = 1}
	local job = VideoExportJob(fake_encoder({}, sizes), fake_graphics({}), function() return 0 end)
	job:start({width = 1, height = 1, fps = 10, duration = 1, path = "o.webp", format = "webp", draw = function() end})
	job:cancel()
	t:eq(job.state, "cancelled")
	t:eq(job:isActive(), false)
	t:eq(sizes[1], "o.webp")
end

return test
