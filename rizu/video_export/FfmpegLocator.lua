local class = require("class")
local jit = require("jit")

---@class rizu.video_export.FfmpegLocator
---@operator call: rizu.video_export.FfmpegLocator
---@field path string
---@field available boolean?
---@field execute fun(command: string): any
local FfmpegLocator = class()

---Quotes a command so it runs the same through `io.popen`/`os.execute` on every platform.
---`cmd.exe /c` strips the outer pair of quotes, so the whole line gets an extra pair there.
---@param command string
---@return string
function FfmpegLocator.shell(command)
	if jit.os == "Windows" then
		return '"' .. command .. '"'
	end
	return command
end

---@param s string
---@return string
function FfmpegLocator.quote(s)
	return '"' .. s:gsub('"', '\\"') .. '"'
end

---@return string
function FfmpegLocator.nullDevice()
	return jit.os == "Windows" and "NUL" or "/dev/null"
end

---@param execute (fun(command: string): any)?
function FfmpegLocator:new(execute)
	self.path = "ffmpeg"
	self.execute = execute or os.execute
end

---@param path string?
function FfmpegLocator:setPath(path)
	self.path = (path and path ~= "") and path or "ffmpeg"
	self.available = nil
end

---Runs `ffmpeg -version`, so a binary that exists but cannot start also counts as missing.
---The result is cached until `setPath` or `refresh`.
---@return boolean
function FfmpegLocator:isAvailable()
	if self.available == nil then
		local command = ("%s -version >%s 2>&1"):format(self.quote(self.path), self.nullDevice())
		local status = self.execute(self.shell(command))
		self.available = status == 0 or status == true
	end
	return self.available
end

function FfmpegLocator:refresh()
	self.available = nil
end

return FfmpegLocator
