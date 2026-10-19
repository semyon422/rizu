local class = require("class")
local path_util = require("path_util")
local OsuSkinIni = require("rizu.skin.OsuSkinIni")
local SkinConfig = require("rizu.skin.SkinConfig")
local Settings = require("rizu.config.Settings")

---"builtin" skins ship with the game, "osu" skins are imported osu! skins, "lua" skins are
---`skin.lua` directories that supply their own renderer.
---@alias rizu.skin.SkinFormat "builtin"|"osu"|"lua"

---@alias rizu.skin.Screen "gameplay"|"preview"

---@class rizu.skin.Skin
---@field path string Unique id, also the value stored in settings.
---@field name string
---@field author string?
---@field version string?
---@field format rizu.skin.SkinFormat
---@field gamemode string? builtin and lua skins. An osu! skin renders every osu!-based gamemode.
---@field input_modes string[]? lua skins. nil means any.
---@field skin_ini rizu.skin.OsuSkinIni.Data? osu skins
---@field files string[]? osu skins, relative paths. Indexed on first access.
---@field load (fun(api: rizu.api.GameApi, directory: string, input_mode: string, config: rizu.skin.SkinConfig, screen: rizu.skin.Screen): rizu.gameplay.views.PlayfieldRenderer)? lua skins, they get the game api and never the game

---@class rizu.skin.SkinRegistry
---@operator call: rizu.skin.SkinRegistry
---@field fs fs.IFilesystem
---@field settings rizu.config.Config
---@field paths rizu.config.StringMap Skin choices from settings, kept current so resolve() does not copy the map per frame.
---@field skins rizu.skin.Skin[]
---@field listeners {[fun()]: true}
local SkinRegistry = class()

local OSU_GAMEMODES = {mania = true, osu = true, taiko = true, catch = true}

---Which settings key stores the skin for a gamemode.
---@param gamemode string
---@param input_mode string
---@return string
local function settingKey(gamemode, input_mode)
	if gamemode == "mania" then return "mania/" .. input_mode end
	return ({osu = "osu/1osu", taiko = "osu/1taiko", catch = "osu/1fruits"})[gamemode] or gamemode
end

---@param path string?
---@return string?
local function normalize(path)
	return path and path:gsub("\\", "/"):gsub("/+$", "")
end

---@param skin rizu.skin.Skin
---@param gamemode string
---@param input_mode string
---@return boolean
local function supports(skin, gamemode, input_mode)
	if skin.format == "osu" then return OSU_GAMEMODES[gamemode] == true end
	if skin.gamemode ~= gamemode then return false end
	if not skin.input_modes then return true end
	for _, supported in ipairs(skin.input_modes) do
		if supported == input_mode or supported == "any" then return true end
	end
	return false
end

---@param fs fs.IFilesystem
---@param directory string
---@param relative string?
---@param files string[]
local function indexFiles(fs, directory, relative, files)
	for _, name in ipairs(fs:getDirectoryItems(directory)) do
		local path = path_util.join(directory, name)
		local relative_path = relative and path_util.join(relative, name) or name
		local info = fs:getInfo(path)
		if info and info.type == "directory" then
			indexFiles(fs, path, relative_path, files)
		elseif info then
			table.insert(files, relative_path)
		end
	end
	return files
end

---@param fs fs.IFilesystem
---@param settings rizu.config.Config
---@param path string?
function SkinRegistry:new(fs, settings, path)
	self.fs = fs
	self.settings = settings
	self.paths = settings:getStringMap(Settings.keys.gameplay.skins)
	settings:subscribeStringMap(Settings.keys.gameplay.skins, function(value)
		self.paths = value
		self:notify()
	end)
	self.skins_rizu_path = path_util.join(path or "userdata/dlc", "skins_rizu")
	self.skins_osu_path = path_util.join(path or "userdata/dlc", "skins_osu")
	self.skins_user_path = "userdata/skins"
	self.skins = {}
	self.listeners = {}
end

---Called when the skin list or the selected skins change.
---@param listener fun()
---@return fun() unsubscribe
function SkinRegistry:onChanged(listener)
	self.listeners[listener] = true
	return function() self.listeners[listener] = nil end
end

function SkinRegistry:notify()
	for listener in pairs(self.listeners) do listener() end
end

---Only skin.ini is read here: listing skins must stay cheap, the file index is built on first use.
---@param directory string
---@return rizu.skin.Skin?
function SkinRegistry:readOsuSkin(directory)
	local ini_name
	for _, name in ipairs(self.fs:getDirectoryItems(directory)) do
		-- osu! only recognizes skin.ini in the skin root, in any case: it normally runs on Windows.
		if name:lower() == "skin.ini" then ini_name = name break end
	end
	local source = ini_name and self.fs:read(path_util.join(directory, ini_name))
	if not source or #source > 1024 * 1024 then return end

	local skin_ini = OsuSkinIni.parse(source)
	local general = skin_ini.General
	local fs = self.fs
	return setmetatable({
		path = directory,
		name = general.Name and general.Name ~= "" and general.Name or directory:match("([^/]+)$"),
		author = general.Author,
		version = general.Version,
		format = "osu",
		skin_ini = skin_ini,
	}, {__index = function(skin, key)
		if key ~= "files" then return end
		local files = indexFiles(fs, directory, nil, {})
		table.sort(files)
		rawset(skin, "files", files)
		return files
	end})
end

---@param directory string
---@return rizu.skin.Skin?
function SkinRegistry:readLuaSkin(directory)
	local path = path_util.join(directory, "skin.lua")
	local source = self.fs:read(path)
	if not source then return end
	local ok, definition = pcall(function()
		local def = assert(loadstring(source, "@" .. path))()
		assert(type(def) == "table" and type(def.name) == "string" and type(def.gamemode) == "string"
			and type(def.load) == "function", "skin.lua must return {name, gamemode, input_modes?, load}")
		return def
	end)
	if not ok then
		print(("skin %s: %s"):format(path, tostring(definition)))
		return
	end
	return {
		path = directory,
		name = definition.name,
		author = definition.author,
		version = definition.version,
		format = "lua",
		gamemode = definition.gamemode,
		input_modes = definition.input_modes,
		load = definition.load,
	}
end

---@param directory string
---@param read fun(self: rizu.skin.SkinRegistry, directory: string): rizu.skin.Skin?
---@param skins rizu.skin.Skin[]
function SkinRegistry:scan(directory, read, skins)
	if not self.fs:getInfo(directory) then return end
	for _, name in ipairs(self.fs:getDirectoryItems(directory)) do
		local path = path_util.join(directory, name)
		local info = self.fs:getInfo(path)
		local skin = info and info.type == "directory" and read(self, path)
		if skin then table.insert(skins, skin) end
	end
	table.sort(skins, function(a, b) return a.path < b.path end)
end

function SkinRegistry:load()
	local builtin = {
		{path = "builtin/mania", name = "Rizu Default", author = "Rizu", format = "builtin", gamemode = "mania"},
		{path = "builtin/sdvx", name = "Rizu SDVX", author = "Rizu", format = "builtin", gamemode = "sdvx"},
	}
	local lua_skins, osu_skins = {}, {}
	self:scan(self.skins_rizu_path, self.readLuaSkin, lua_skins)
	self:scan(self.skins_osu_path, self.readOsuSkin, osu_skins)
	self:scan(self.skins_user_path, self.readOsuSkin, osu_skins)
	self.skins = builtin
	table.move(lua_skins, 1, #lua_skins, #self.skins + 1, self.skins)
	table.move(osu_skins, 1, #osu_skins, #self.skins + 1, self.skins)
	self:notify()
end

---@return rizu.skin.Skin[]
function SkinRegistry:getSkins()
	return self.skins
end

---@param path string?
---@return rizu.skin.Skin?
function SkinRegistry:getSkin(path)
	path = normalize(path)
	for _, skin in ipairs(self.skins) do
		if skin.path == path then return skin end
	end
end

---Skins the player can pick for this gamemode, in display order. Empty for gamemodes with no skin.
---@param gamemode string
---@param input_mode string
---@return rizu.skin.Skin[]
function SkinRegistry:getSkinsFor(gamemode, input_mode)
	local list = {}
	for _, skin in ipairs(self.skins) do
		if supports(skin, gamemode, input_mode) then table.insert(list, skin) end
	end
	return list
end

---The skin that draws this gamemode, from settings. A missing or stale choice falls back to the
---built-in skin, and for osu!-based gamemodes to the first imported osu! skin, if any.
---@param gamemode string
---@param input_mode string
---@return rizu.skin.Skin?
function SkinRegistry:resolve(gamemode, input_mode)
	local paths = self.paths
	-- One choice for the whole osu! family unless a gamemode has its own.
	local family = gamemode ~= "mania" and (paths["osu/1osu"] or paths.osu) or nil
	for _, path in ipairs({paths[settingKey(gamemode, input_mode)] or false, family or false}) do
		local skin = path and self:getSkin(path)
		if skin and supports(skin, gamemode, input_mode) then return skin end
	end
	for _, skin in ipairs(self:getSkinsFor(gamemode, input_mode)) do
		return skin
	end
end

---@param gamemode string
---@param input_mode string
---@param skin rizu.skin.Skin
function SkinRegistry:select(gamemode, input_mode, skin)
	local paths = self.settings:getStringMap(Settings.keys.gameplay.skins)
	paths[settingKey(gamemode, input_mode)] = skin.path
	self.settings:setStringMap(Settings.keys.gameplay.skins, paths)
end

---@param skin rizu.skin.Skin?
---@return string
function SkinRegistry:getConfigPath(skin)
	if not skin or skin.format == "builtin" then
		return path_util.join(self.skins_rizu_path, "base/rizu_mania.skin-config.json")
	end
	return path_util.join(skin.path, "skin-config.json")
end

---Builds the renderer for a skin. The config is returned only for the gamemode that has skin settings.
---@param skin rizu.skin.Skin?
---@param game sphere.GameController
---@param gamemode string
---@param input_mode string
---@param screen rizu.skin.Screen
---@return rizu.gameplay.views.PlayfieldRenderer renderer
---@return rizu.skin.SkinConfig? config
---@return string? config_path
function SkinRegistry:createRenderer(skin, game, gamemode, input_mode, screen)
	if gamemode ~= "mania" and not (skin and skin.format == "lua") then
		local renderer
		if gamemode == "osu" then
			renderer = require("rizu.skin.osu.OsuAimRenderer")(game, skin)
		elseif gamemode == "taiko" then
			renderer = require("rizu.skin.osu.OsuTaikoRenderer")(game, skin)
		elseif gamemode == "catch" then
			renderer = require("rizu.skin.osu.OsuFruitsRenderer")(game, skin)
		else
			assert(gamemode == "sdvx", "no renderer for gamemode " .. tostring(gamemode))
			renderer = require("rizu.skin.base.SdvxRenderer")(game)
		end
		return renderer
	end

	local config = SkinConfig()
	local config_path = self:getConfigPath(skin)
	if self.fs:getInfo(config_path) then
		local loaded, load_error = config:load(self.fs, config_path)
		if not loaded then
			print(("could not load skin config %s: %s"):format(config_path, tostring(load_error)))
		end
	end

	local renderer
	if skin and skin.format == "lua" then
		renderer = skin.load(game.api, skin.path, input_mode, config, screen)
	elseif skin and skin.format == "osu" then
		renderer = require("rizu.skin.osu.OsuManiaRenderer")(game, skin, input_mode, config, config_path)
	else
		renderer = require("rizu.skin.base.ManiaPlayfieldRenderer")(game, input_mode, screen, config, config_path)
	end
	return renderer, config, config_path
end

return SkinRegistry
