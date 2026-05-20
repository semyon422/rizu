local SkinInfo = require("sphere.models.NoteSkinModel.SkinInfo")
local InputMode = require("chart.core.InputMode")

---@class sphere.LuaSkinInfo: sphere.SkinInfo
---@operator call: sphere.LuaSkinInfo
local LuaSkinInfo = SkinInfo + {}

function LuaSkinInfo:load()
	local path = self:getPath()
	local noteSkin = assert(love.filesystem.load(path))(path)

	self.name = noteSkin.name
	self.inputMode = noteSkin.inputMode
end

---@param inputMode string
---@return boolean
function LuaSkinInfo:matchInput(inputMode)
	if type(self.inputMode) == "function" then
		return self.inputMode(inputMode)
	end
	return self.inputMode == inputMode
end

---@param inputMode string
---@return sphere.OsuNoteSkin?
function LuaSkinInfo:loadSkin(inputMode)
	local path = self:getPath()
	print("load " .. path)
	local noteSkin = assert(love.filesystem.load(path))(path)

	noteSkin.path = path
	noteSkin.directoryPath = self.dir
	noteSkin.fileName = self.file_name
	noteSkin:load(inputMode)

	return noteSkin
end

return LuaSkinInfo
