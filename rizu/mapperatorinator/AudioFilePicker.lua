local FilePicker = require("rizu.mapperatorinator.FilePicker")

---@class rizu.mapperatorinator.AudioFilePicker
---@operator call: rizu.mapperatorinator.AudioFilePicker
local AudioFilePicker = FilePicker + {}

---@param callback rizu.mapperatorinator.FileDialogCallback
function AudioFilePicker:pick(callback)
	self:open("Select audio for Mapperatorinator", {
		["Audio files"] = "mp3;wav;ogg;m4a;flac",
	}, callback)
end

return AudioFilePicker
