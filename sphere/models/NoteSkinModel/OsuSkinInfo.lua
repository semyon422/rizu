local SkinInfo = require("sphere.models.NoteSkinModel.SkinInfo")
local OsuNoteSkin = require("sphere.models.NoteSkinModel.OsuNoteSkin")
local OsuSpriteRepo = require("sphere.models.NoteSkinModel.osu.OsuSpriteRepo")
local OsuSpriteLocator = require("sphere.models.NoteSkinModel.osu.OsuSpriteLocator")
local utf8validate = require("utf8validate")
local InputMode = require("chart.core.InputMode")

---@class sphere.OsuSkinInfo: sphere.SkinInfo
---@operator call: sphere.OsuSkinInfo
local OsuSkinInfo = SkinInfo + {}

function OsuSkinInfo:load()
	local content = love.filesystem.read(self:getPath())
	content = utf8validate(content)
	local skinini = OsuNoteSkin:parseSkinIni(content)

	self.name = skinini.General.Name
end

---@param inputMode string
---@return boolean
function OsuSkinInfo:matchInput(inputMode)
	return true
end

---@param sprites_repo sphere.OsuSpriteRepo?
function OsuSkinInfo:setDefaultSpritesRepo(sprites_repo)
	self.sprites_repo = sprites_repo
end

---@param inputMode string
---@return sphere.OsuNoteSkin?
function OsuSkinInfo:loadSkin(inputMode)
	local _inputMode = InputMode(inputMode)

	local path = self:getPath()
	print("load " .. path)

	local content = love.filesystem.read(path)
	content = utf8validate(content)
	local skinini = OsuNoteSkin:parseSkinIni(content)

	local locator = OsuSpriteLocator()
	locator:addSpriteRepo(OsuSpriteRepo(self.dir, self.files))
	locator:addSpriteRepo(self.sprites_repo)

	local noteSkin = OsuNoteSkin()
	noteSkin.sprite_locator = locator
	noteSkin.path = path
	noteSkin.directoryPath = self.dir
	noteSkin.fileName = self.file_name
	noteSkin.skinini = skinini
	noteSkin:setKeys(_inputMode:getColumns())
	noteSkin.inputMode = _inputMode
	local ok, err = xpcall(noteSkin.load, debug.traceback, noteSkin)
	if not ok then
		print(err)
		return
	end

	return noteSkin
end

return OsuSkinInfo
