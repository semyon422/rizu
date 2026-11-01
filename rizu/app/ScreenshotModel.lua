local class = require("class")
local Observable = require("Observable")

---@class rizu.ScreenshotModel
---@operator call: rizu.ScreenshotModel
---@field lastSavedImagePath string?
---@field onSaved util.Observable Sends {path = string}, the saved file in the game's save directory.
local ScreenshotModel = class()

function ScreenshotModel:new()
	self.onSaved = Observable()
end

local prefix = "userdata/screenshots/screenshot "
local path_fmt = prefix .. "%s.png"
local pathn_fmt = prefix .. "%s (%s).png"

---@return string
local function get_path()
	local date = os.date("%d.%m.%Y %H-%M-%S")

	local path = path_fmt:format(date)
	local info = love.filesystem.getInfo(path, "file")
	if not info then
		return path
	end

	for i = 2, 10 do
		path = pathn_fmt:format(date, i)
		info = love.filesystem.getInfo(path, "file")
		if not info then
			return path
		end
	end

	return pathn_fmt:format(date, "?")
end

---Opens a saved screenshot in the system viewer.
---@param path string As onSaved sends it.
function ScreenshotModel.open(path)
	love.system.openURL("file://" .. love.filesystem.getSource() .. "/" .. path)
end

---@param open boolean?
function ScreenshotModel:capture(open)
	love.graphics.captureScreenshot(function(imageData)
		local path = get_path()
		local fileData = imageData:encode("png")
		assert(love.filesystem.write(path, fileData:getString()))
		if open then
			ScreenshotModel.open(path)
		end
		self.lastSavedImagePath = path
		self.onSaved:send({path = path})
	end)
end

return ScreenshotModel
