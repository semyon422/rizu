local class = require("class")

---@alias rizu.video_export.State "idle" | "running" | "finishing" | "done" | "failed" | "cancelled"

---@class rizu.video_export.Options
---@field width integer
---@field height integer
---@field fps number
---@field duration number Seconds of output.
---@field start_time number? Passed to `draw` as the time of the first frame.
---@field path string
---@field format rizu.video_export.Format
---@field draw fun(time: number, dt: number, width: integer, height: integer) Draws one frame into the current canvas.
---@field clear_color number[]? Canvas color before each frame. Opaque black by default.

---@class rizu.video_export.VideoExportJob
---@operator call: rizu.video_export.VideoExportJob
---@field state rizu.video_export.State
---@field error string?
---@field frame integer Frames written so far.
---@field frames integer Total frames.
local VideoExportJob = class()

---@param encoder rizu.video_export.FfmpegEncoder
---@param graphics table love.graphics, or a stand-in with the same functions
---@param clock fun(): number Seconds, used for the per-step time budget.
function VideoExportJob:new(encoder, graphics, clock)
	self.encoder = encoder
	self.graphics = graphics or love.graphics
	self.clock = clock or os.clock
	self.state = "idle"
	self.frame = 0
	self.frames = 0
end

---@param options rizu.video_export.Options
---@return boolean ok
---@return string? error
function VideoExportJob:start(options)
	assert(self.state == "idle", "job already started")
	self.options = options
	self.frames = math.max(1, math.ceil(options.duration * options.fps))
	local ok, err = self.encoder:open(options)
	if not ok then
		return self:fail(err)
	end
	self.canvas = self.graphics.newCanvas(options.width, options.height)
	self.state = "running"
	return true
end

---@private
---@param err string?
---@return false
---@return string
function VideoExportJob:fail(err)
	self.state = "failed"
	self.error = err or "unknown error"
	self.encoder:abort()
	self:release()
	return false, self.error
end

---@private
function VideoExportJob:release()
	if self.canvas then
		self.canvas:release()
		self.canvas = nil
	end
end

---@private
---@return boolean ok
---@return string? error
function VideoExportJob:renderFrame()
	local o = self.options
	local g = self.graphics
	local dt = 1 / o.fps
	local time = (o.start_time or 0) + self.frame * dt

	g.push("all")
	g.setCanvas(self.canvas)
	local c = o.clear_color or {0, 0, 0, 1}
	g.clear(c[1], c[2], c[3], c[4])
	g.origin()
	local ok, err = pcall(o.draw, time, dt, o.width, o.height)
	g.pop()
	if not ok then
		return false, tostring(err)
	end

	local data = g.readbackTexture(self.canvas)
	local bytes = data:getString()
	data:release()
	return self.encoder:write(bytes)
end

---Renders frames until `budget` seconds have passed, then returns so the UI can keep updating.
---At least one frame is rendered per call.
---@param budget number?
function VideoExportJob:step(budget)
	if self.state == "finishing" then
		local ok, err = self.encoder:close()
		if ok then
			self.state = "done"
			self:release()
		else
			self:fail(err)
		end
		return
	end
	if self.state ~= "running" then
		return
	end

	local deadline = self.clock() + (budget or 0.008)
	repeat
		local ok, err = self:renderFrame()
		if not ok then
			self:fail(err)
			return
		end
		self.frame = self.frame + 1
		if self.frame >= self.frames then
			-- Encoding the animation happens when the input ends, which can take a while.
			-- A separate state lets the UI show that before the call blocks.
			self.state = "finishing"
			return
		end
	until self.clock() >= deadline
end

function VideoExportJob:cancel()
	if self.state == "running" or self.state == "finishing" then
		self.state = "cancelled"
		self.encoder:abort()
		self:release()
	end
end

---@return number progress 0..1
function VideoExportJob:getProgress()
	if self.frames == 0 then return 0 end
	return self.frame / self.frames
end

---@return boolean
function VideoExportJob:isActive()
	return self.state == "running" or self.state == "finishing"
end

return VideoExportJob
