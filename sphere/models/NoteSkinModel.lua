local class = require("class")
local path_util = require("path_util")
local BaseNoteSkin = require("sphere.models.NoteSkinModel.BaseNoteSkin")
local LuaSkinInfo = require("sphere.models.NoteSkinModel.LuaSkinInfo")
local OsuSkinInfo = require("sphere.models.NoteSkinModel.OsuSkinInfo")
local BaseSkinInfo = require("sphere.models.NoteSkinModel.BaseSkinInfo")
local OsuSpriteRepo = require("sphere.models.NoteSkinModel.osu.OsuSpriteRepo")
local path_util = require("path_util")

---@class sphere.NoteSkinModel
---@operator call: sphere.NoteSkinModel
local NoteSkinModel = class()

---@param configModel sphere.ConfigModel
---@param packageManager rizu.PackageManager
function NoteSkinModel:new(configModel, packageManager)
	self.configModel = configModel
	self.packageManager = packageManager
	self.items = {}
end

NoteSkinModel.path = "userdata/skins"

function NoteSkinModel:load()
	self.inputMode = nil
	self.config = self.configModel.configs.settings

	local tree = {}
	self:lookupTree(self.path, tree)

	self:loadOsuSpritesRepo()

	self.skinInfos = {}
	self:lookupSkins(tree)

	self:loadSkins()
end

---@param tree table
---@param list table
---@param prefix string?
local function tree_to_list(tree, list, prefix)
	for _, item in ipairs(tree) do
		if type(item) == "string" then
			table.insert(list, path_util.join(prefix, item))
		elseif type(item) == "table" then
			tree_to_list(item, list, path_util.join(prefix, item.name))
		end
	end
end

function NoteSkinModel:loadOsuSpritesRepo()
	local osu_ui_dir = self.packageManager:getPackageDir("osu_ui")
	if not osu_ui_dir then
		return
	end

	local path = path_util.join(osu_ui_dir, "osu_ui", "assets")

	local tree = {}
	self:lookupTree(path, tree)

	local list = {}
	tree_to_list(tree, list)

	self.osuSpriteRepo = OsuSpriteRepo(path, list)
end

---@param directoryPath string
---@param tree table
function NoteSkinModel:lookupTree(directoryPath, tree)
	local items = love.filesystem.getDirectoryItems(directoryPath)

	for _, name in ipairs(items) do
		local path = directoryPath .. "/" .. name
		local info = love.filesystem.getInfo(path)
		if info and info.type == "file" then
			table.insert(tree, name)
		elseif info and info.type == "directory" and name ~= "__MACOSX" then
			local dir = {name = name}
			table.insert(tree, dir)
			self:lookupTree(path, dir)
		end
	end
end

---@param path string
---@return sphere.SkinInfo?
function NoteSkinModel:newSkinInfo(path)
	path = path:lower()

	---@type sphere.SkinInfo?
	local skin_info

	if path:find("^.+%.lua$") then
		skin_info = LuaSkinInfo()
	elseif path:find("^.+%.ini$") then
		skin_info = OsuSkinInfo()
		skin_info:setDefaultSpritesRepo(self.osuSpriteRepo)
	end

	return skin_info
end

---@param tree table
---@param prefix string?
function NoteSkinModel:lookupSkins(tree, prefix)
	local found = {}
	for _, item in ipairs(tree) do
		if type(item) == "string" and item:lower():find("^.-skin%.%a-$") then
			local info = self:newSkinInfo(item)
			if info then
				info.file_name = item
				info.dir = path_util.join(self.path, prefix)
				table.insert(found, info)
				table.insert(self.skinInfos, info)
			end
		end
	end

	if #found > 0 then
		local list = {}
		tree_to_list(tree, list)
		table.sort(list)

		for _, info in ipairs(found) do
			info.files = list
		end
	end

	for _, item in ipairs(tree) do
		if type(item) == "table" then
			self:lookupSkins(item, path_util.join(prefix, item.name))
		end
	end
end

function NoteSkinModel:loadSkins()
	for _, skinInfo in ipairs(self.skinInfos) do
		skinInfo:load()
	end
end

---@param inputMode string
---@return table
function NoteSkinModel:getSkinInfos(inputMode)
	if self.inputMode == inputMode then
		return self.items
	end
	self.inputMode = inputMode

	local items = {}
	self.items = items

	items[1] = BaseSkinInfo()
	for _, skinInfo in ipairs(self.skinInfos) do
		if skinInfo:matchInput(inputMode) then
			table.insert(items, skinInfo)
		end
	end

	return items
end

---@param inputMode string
---@param path string
function NoteSkinModel:setDefaultNoteSkin(inputMode, path)
	self.config.gameplay["noteskin" .. inputMode] = path
end

---@param inputMode string
---@return sphere.NoteSkin
function NoteSkinModel:getNoteSkin(inputMode)
	local skinInfos = self:getSkinInfos(inputMode)

	local sel_path = self.config.gameplay["noteskin" .. inputMode]
	if sel_path then
		for _, skinInfo in ipairs(skinInfos) do
			if skinInfo:getPath() == sel_path then
				if not self.noteSkin or self.noteSkin.path ~= sel_path then
					self.noteSkin = skinInfo:loadSkin(inputMode)
				end
				return self.noteSkin
			end
		end
	end

	if #skinInfos ~= 0 then
		self:setDefaultNoteSkin(inputMode, skinInfos[1]:getPath())
	end

	self.noteSkin = skinInfos[1]:loadSkin(inputMode)
	return self.noteSkin
end

---@param inputMode string
---@return sphere.SkinInfo
function NoteSkinModel:getSkinInfo(inputMode)
	local skinInfos = self:getSkinInfos(inputMode)

	local sel_path = self.config.gameplay["noteskin" .. inputMode]
	if sel_path then
		for _, skinInfo in ipairs(skinInfos) do
			if skinInfo:getPath() == sel_path then
				return skinInfo
			end
		end
	end

	return skinInfos[1]
end

---@param inputMode string
---@return sphere.NoteSkin
function NoteSkinModel:loadNoteSkin(inputMode)
	local skinInfo = self:getSkinInfo(inputMode)
	self.noteSkin = skinInfo:loadSkin(inputMode)
	return self.noteSkin
end

return NoteSkinModel
