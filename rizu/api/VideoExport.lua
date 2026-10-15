local FfmpegEncoder = require("rizu.video_export.FfmpegEncoder")
local FfmpegLocator = require("rizu.video_export.FfmpegLocator")
local VideoExportJob = require("rizu.video_export.VideoExportJob")
local class = require("class")

--[[
Turns frames a user interface draws into an animated WebP or an MP4 (no audio), with the system's `ffmpeg`.
The game does not draw anything: the UI supplies a function that draws one frame, so a custom UI can
put its own fonts, sprites and layout into the animation.

	local export = ui.api.video_export
	if not export:isAvailable() then return showInstallHint() end
	local ok, err = export:start({
		width = 640, height = 360, fps = 30, duration = 5, start_time = chart.preview_time,
		draw = function(time, dt, width, height)
			drawMyFrame(time, width, height)
		end,
	})
	-- every frame while the export runs
	export:update()
	progressBar:setValue(export:getProgress())

`draw` runs with the export canvas as the render target, at the export size and not the window size.
The canvas is cleared before each call. Graphics state is restored after each call. `time` is the preview time of the
frame, in seconds from the start of the audio file. Only one export runs at a time.
]]

---@alias rizu.api.VideoExport.State rizu.video_export.State

---@class rizu.api.VideoExport
---@operator call: rizu.api.VideoExport
---@field private locator rizu.video_export.FfmpegLocator
---@field private job rizu.video_export.VideoExportJob?
---@field private outputPath string?
local VideoExport = class()

local DIRECTORY = "userdata/export"

function VideoExport:new()
	self.locator = FfmpegLocator()
end

---Whether `ffmpeg` can be started. Cached; call `refresh` after the user installs it.
---@return boolean
function VideoExport:isAvailable() return self.locator:isAvailable() end

function VideoExport:refresh() self.locator:refresh() end

---Use another `ffmpeg` than the one on `PATH`. An empty string goes back to `PATH`.
---@param path string?
function VideoExport:setFfmpegPath(path) self.locator:setPath(path) end

---A path for a new file in `userdata/export`, as the operating system sees it.
---@param name string Without extension; characters a file name cannot hold are replaced.
---@return string
function VideoExport:makePath(name, extension)
	love.filesystem.createDirectory(DIRECTORY)
	name = name:gsub('[<>:"/\\|?*%c]', "_")
	return ("%s/%s/%s.%s"):format(love.filesystem.getSource(), DIRECTORY, name, extension or "webp")
end

---@class rizu.api.VideoExport.Options
---@field width integer
---@field height integer
---@field fps number
---@field duration number Seconds of animation.
---@field start_time number? The `time` of the first frame.
---@field format rizu.video_export.Format? `webp` by default, or `mp4`; `path` must match.
---@field path string? From `makePath`. A file in `userdata/export` when left out.
---@field draw fun(time: number, dt: number, width: integer, height: integer) Draws one frame.
---@field clear_color number[]? RGBA the canvas is cleared with, opaque black when left out.

---@param options rizu.api.VideoExport.Options
---@return boolean ok
---@return string? error
function VideoExport:start(options)
	if self.job and self.job:isActive() then
		return false, "an export is already running"
	end
	if not self:isAvailable() then
		return false, "ffmpeg was not found"
	end
	local path = options.path or self:makePath(os.date("export %Y-%m-%d %H-%M-%S"))
	local job = VideoExportJob(FfmpegEncoder(self.locator), love.graphics, love.timer.getTime)
	self.job = job
	self.outputPath = path
	return job:start({
		width = options.width,
		height = options.height,
		fps = options.fps,
		duration = options.duration,
		start_time = options.start_time,
		path = path,
		format = options.format or "webp",
		draw = options.draw,
		clear_color = options.clear_color,
	})
end

---Renders some frames. Call it once per update while `isRunning()`; it spends about `budget` seconds.
---@param budget number? Seconds, 0.008 by default.
function VideoExport:update(budget)
	if self.job then self.job:step(budget) end
end

---True from `start` until the file is written, an error happens or `cancel` is called.
---@return boolean
function VideoExport:isRunning() return self.job ~= nil and self.job:isActive() end

---`idle` before any export, `running`, `finishing` (ffmpeg is writing the file; this can take a while and
---the UI stops updating during it), then `done`, `failed` or `cancelled`.
---@return rizu.api.VideoExport.State
function VideoExport:getState() return self.job and self.job.state or "idle" end

---@return number progress 0..1
function VideoExport:getProgress() return self.job and self.job:getProgress() or 0 end

---@return string? error Set when the state is `failed`.
function VideoExport:getError() return self.job and self.job.error or nil end

---@return string? path The file of the last export, as the operating system sees it.
function VideoExport:getOutputPath() return self.outputPath end

---Stops the export and deletes the unfinished file.
function VideoExport:cancel()
	if self.job then self.job:cancel() end
end

return VideoExport
