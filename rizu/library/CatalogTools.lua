local class = require("class")

---The programs the catalog is built with: coreutils for hashes and FFmpeg for the assets.
---@class rizu.library.CatalogTools
---@operator call: rizu.library.CatalogTools
---@field ffmpeg string
local CatalogTools = class()

CatalogTools.audio_bitrate = "96k"
CatalogTools.preview_length = 20

---@param ffmpeg string?
function CatalogTools:new(ffmpeg)
	self.ffmpeg = ffmpeg or "ffmpeg"
end

---@param s string
---@return string
function CatalogTools.quote(s)
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

---@param command string
---@return boolean
local function succeeded(command)
	local ok, _, code = os.execute(command)
	return ok == true or ok == 0 or code == 0
end

---@param algorithm "md5"|"sha256"
---@param path string
---@return string
function CatalogTools:hashFile(algorithm, path)
	local pipe = assert(io.popen(("%ssum -- %s"):format(algorithm, self.quote(path))))
	local output = pipe:read("*a")
	pipe:close()
	return assert(output:match("^(%x+)"), "could not hash " .. path)
end

---@param algorithm "md5"|"sha256"
---@param s string
---@return string
function CatalogTools:hashString(algorithm, s)
	local path = os.tmpname()
	local file = assert(io.open(path, "wb"))
	file:write(s)
	file:close()
	local hash = self:hashFile(algorithm, path)
	os.remove(path)
	return hash
end

---Writes through a temporary file, so an interrupted run leaves no half-written asset behind.
---@param arguments string
---@param output_path string
---@param extension string
---@return boolean ok
---@return string? err
function CatalogTools:run(arguments, output_path, extension)
	local temporary_path = output_path .. ".tmp." .. extension
	os.remove(temporary_path)
	local command = ("%s -loglevel error -y %s %s"):format(self.quote(self.ffmpeg), arguments, self.quote(temporary_path))
	if not succeeded(command) then
		os.remove(temporary_path)
		return false, "ffmpeg failed: " .. command
	end
	assert(os.rename(temporary_path, output_path))
	return true
end

---@param source_path string
---@param output_path string
---@param preview_start number? Seconds. Encodes a preview of this place instead of the whole file.
---@return boolean ok
---@return string? err
function CatalogTools:encodeAudio(source_path, output_path, preview_start)
	local seek = preview_start and ("-ss %s -t %d"):format(preview_start, self.preview_length) or ""
	local arguments = ("-i %s %s -map_metadata -1 -vn -c:a libopus -b:a %s -vbr on -compression_level 10 "
		.. "-application audio -ar 48000 -ac 2"):format(self.quote(source_path), seek, self.audio_bitrate)
	return self:run(arguments, output_path, "webm")
end

---@param source_path string
---@param output_path string
---@return boolean ok
---@return string? err
function CatalogTools:encodeBackground(source_path, output_path)
	local arguments = ("-i %s -frames:v 1 -vf scale=-2:800:flags=lanczos -c:v libaom-av1 -still-picture 1 "
		.. "-crf 36 -cpu-used 6 -pix_fmt yuv420p -map_metadata -1"):format(self.quote(source_path))
	return self:run(arguments, output_path, "avif")
end

return CatalogTools
