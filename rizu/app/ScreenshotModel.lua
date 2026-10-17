local class = require("class")

---@class rizu.ScreenshotModel
---@operator call: rizu.ScreenshotModel
---@field lastSavedImagePath string?
local ScreenshotModel = class()

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

---@param open boolean?
function ScreenshotModel:capture(open)
	love.graphics.captureScreenshot(function(imageData)
		local path = get_path()
		local fileData = imageData:encode("png")
		assert(love.filesystem.write(path, fileData:getString()))
		if open then
			love.system.openURL("file://" .. love.filesystem.getSource() .. "/" .. path)
		end
		self.lastSavedImagePath = path
	end)
end

return ScreenshotModel
