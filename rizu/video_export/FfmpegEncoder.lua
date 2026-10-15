local class = require("class")
local FfmpegLocator = require("rizu.video_export.FfmpegLocator")
local jit = require("jit")

---@class rizu.video_export.FfmpegEncoder
---@operator call: rizu.video_export.FfmpegEncoder
---@field pipe file*?
---@field error string?
---@field outputPath string
---@field logPath string
local FfmpegEncoder = class()

---@alias rizu.video_export.Format "mp4" | "webp"

---H.264 in yuv420p plays everywhere, Discord included. It needs even dimensions. x264 encodes while the frames
---arrive, so closing the pipe is quick. There is no audio: the preview of many charts is a mix of samples
---that is not a file (see `spec.md`).
---@type {[rizu.video_export.Format]: string}
FfmpegEncoder.codecArgs = {
	webp = "-c:v libwebp_anim -lossless 0 -q:v 15 -compression_level 4 -loop 0 -an",
	mp4 = "-c:v libx264 -crf 23 -preset veryfast -pix_fmt yuv420p -movflags +faststart -an",
}

---@param locator rizu.video_export.FfmpegLocator
---@param popen (fun(command: string, mode: string): file*?, string?)?
---@param fileSize (fun(path: string): integer?)?
---@param remove (fun(path: string))?
function FfmpegEncoder:new(locator, popen, fileSize, remove)
	self.locator = locator
	self.popen = popen or io.popen
	self.remove = remove or os.remove
	self.fileSize = fileSize or function(path)
		local f = io.open(path, "rb")
		if not f then return nil end
		local size = f:seek("end")
		f:close()
		return size
	end
end

---@param options {width: integer, height: integer, fps: number, format: rizu.video_export.Format, path: string}
---@return boolean ok
---@return string? error
function FfmpegEncoder:open(options)
	local codec = self.codecArgs[options.format]
	if not codec then
		return false, "unsupported format: " .. tostring(options.format)
	end
	self.outputPath = options.path
	self.logPath = options.path .. ".log"
	-- stderr goes to a log file because a write-mode pipe cannot read it back
	local command = ("%s -loglevel error -y -f rawvideo -pix_fmt rgba -s %dx%d -r %s -i - %s %s 2>%s"):format(
		FfmpegLocator.quote(self.locator.path),
		options.width, options.height, tostring(options.fps),
		codec,
		FfmpegLocator.quote(options.path),
		FfmpegLocator.quote(self.logPath)
	)
	-- Windows text mode turns every 0x0A byte of the pixel data into 0x0D 0x0A, so it needs "b".
	-- glibc popen rejects "wb" with EINVAL, so the mode depends on the OS.
	local mode = jit.os == "Windows" and "wb" or "w"
	local pipe, err = self.popen(FfmpegLocator.shell(command), mode)
	if not pipe then
		return false, err or "failed to start ffmpeg"
	end
	self.pipe = pipe
	return true
end

---@param bytes string raw RGBA, width * height * 4 bytes
---@return boolean ok
---@return string? error
function FfmpegEncoder:write(bytes)
	if not self.pipe then
		return false, "encoder is not open"
	end
	local ok, err = self.pipe:write(bytes)
	if not ok then
		self.error = err or "ffmpeg closed its input"
		return false, self.error
	end
	return true
end

---Waits for ffmpeg to finish. Success means the output file exists and is not empty.
---@return boolean ok
---@return string? error
function FfmpegEncoder:close()
	if self.pipe then
		self.pipe:close()
		self.pipe = nil
	end
	local size = self.fileSize(self.outputPath)
	if not size or size == 0 then
		return false, self.error or ("ffmpeg produced no output, see " .. self.logPath)
	end
	self.remove(self.logPath)
	return true
end

---Stops the process and deletes the unfinished output.
function FfmpegEncoder:abort()
	if self.pipe then
		self.pipe:close()
		self.pipe = nil
	end
	if self.outputPath then
		self.remove(self.outputPath)
		self.remove(self.logPath)
	end
end

return FfmpegEncoder
