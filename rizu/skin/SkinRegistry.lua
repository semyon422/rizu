local class = require("class")
local path_util = require("path_util")
local OsuSkinIni = require("rizu.skin.OsuSkinIni")

---@class rizu.skin.SkinMetadata
---@field name string
---@field author string?
---@field version string?
---@field gamemode string
---@field input_modes string[]

---@alias rizu.skin.SkinFormat "lua"|"osu"

---@alias rizu.skin.Screen
---| "gameplay"
---| "preview"
---| "editor"

---@class rizu.skin.StepmaniaSkinDiscovery
---@field name string
---@field path string
---@field input_modes string[]

---@class rizu.skin.OsuSkinDiscovery
---@field name string
---@field path string
---@field directory_path string
---@field file_name string
---@field format "osu"
---@field metadata rizu.skin.SkinMetadata
---@field skin_ini rizu.skin.OsuSkinIni.Data

---@class rizu.skin.SkinInfo
---@field path string
---@field directory_path string
---@field file_name string?
---@field format rizu.skin.SkinFormat
---@field metadata rizu.skin.SkinMetadata?
---@field load fun(game: sphere.GameController, input_mode: string, screen: rizu.skin.Screen): unknown

---@class rizu.skin.SkinRegistry
---@operator call: rizu.skin.SkinRegistry
---@field fs fs.IFilesystem
---@field path string
---@field skins rizu.skin.SkinInfo[]
---@field stepmania_skins rizu.skin.StepmaniaSkinDiscovery[]
---@field osu_skins rizu.skin.OsuSkinDiscovery[]
---@field errors {[string]: string}
local SkinRegistry = class()

---@param fs fs.IFilesystem
---@param path string?
function SkinRegistry:new(fs, path)
	self.fs = fs
	self.path = path or "userdata/dlc"
	self.skins_rizu_path = path_util.join(self.path, "skins_rizu")
	self.skins_stepmania_path = path_util.join(self.path, "skins_stepmania")
	self.skins_osu_path = path_util.join(self.path, "skins_osu")
	self.base_path = "rizu/skin/base"
	self.skins = {}
	self.stepmania_skins = {}
	self.osu_skins = {}
	self.errors = {}
end

---@param path string
---@param skin unknown
---@return rizu.skin.SkinInfo?
---@return string?
function SkinRegistry:verify(path, skin)
	if type(skin) ~= "table" then
		return nil, "skin must return a table"
	end

	local metadata = skin.metadata
	if type(metadata) ~= "table" then
		return nil, "skin.metadata must be a table"
	end
	if type(metadata.name) ~= "string" or metadata.name == "" then
		return nil, "skin.metadata.name must be a non-empty string"
	end
	if metadata.author ~= nil and type(metadata.author) ~= "string" then
		return nil, "skin.metadata.author must be a string"
	end
	if metadata.version ~= nil and type(metadata.version) ~= "string" then
		return nil, "skin.metadata.version must be a string"
	end
	if type(metadata.gamemode) ~= "string" or metadata.gamemode == "" then
		return nil, "skin.metadata.gamemode must be a non-empty string"
	end
	if type(metadata.input_modes) ~= "table" or #metadata.input_modes == 0 then
		return nil, "skin.metadata.input_modes must be a non-empty array of strings"
	end
	for _, input_mode in ipairs(metadata.input_modes) do
		if type(input_mode) ~= "string" or input_mode == "" then
			return nil, "skin.metadata.input_modes must be a non-empty array of strings"
		end
	end
	if type(skin.load) ~= "function" then
		return nil, "skin.load must be a function"
	end

	local directory_path, file_name = path:match("^(.*)/([^/]+)$")
	return {
		path = path,
		directory_path = directory_path or "",
		file_name = file_name or path,
		format = "lua",
		metadata = metadata,
		load = skin.load,
	}
end

---@param path string
function SkinRegistry:loadFile(path)
	local source, read_error = self.fs:read(path)
	if not source then
		self.errors[path] = read_error or "could not read skin"
		return
	end
	if #source > 1024 * 1024 then
		self.errors[path] = "skin source exceeds 1 MiB"
		return
	end

	local chunk, load_error = loadstring(source, "@" .. path)
	if not chunk then
		self.errors[path] = load_error
		return
	end

	local ok, skin_or_error = xpcall(chunk, debug.traceback)
	if not ok then
		self.errors[path] = skin_or_error
		return
	end

	local skin, verify_error = self:verify(path, skin_or_error)
	if not skin then
		self.errors[path] = assert(verify_error)
		return
	end
	table.insert(self.skins, skin)
end

---@param skin_directory string
---@param file_name string
function SkinRegistry:loadOsuSkin(skin_directory, file_name)
	local path = path_util.join(skin_directory, file_name)
	local source, read_error = self.fs:read(path)
	if not source then
		self.errors[path] = read_error or "could not read skin.ini"
		return
	end
	if #source > 1024 * 1024 then
		self.errors[path] = "skin.ini exceeds 1 MiB"
		return
	end

	local skin_ini = OsuSkinIni.parse(source)
	local general = skin_ini.General
	local skin_name = general.Name
	if not skin_name or skin_name == "" then
		skin_name = skin_directory:match("([^/]+)$") or skin_directory
	end

	local input_modes = {}
	local seen_input_modes = {}
	for _, mania in ipairs(skin_ini.Mania) do
		local keys = tonumber(mania.Keys)
		if keys and keys > 0 and keys <= 18 and keys == math.floor(keys) then
			local input_mode = tostring(keys) .. "key"
			if not seen_input_modes[input_mode] then
				seen_input_modes[input_mode] = true
				table.insert(input_modes, input_mode)
			end
		end
	end
	table.sort(input_modes, function(a, b)
		return tonumber(a:match("^(%d+)key$")) < tonumber(b:match("^(%d+)key$"))
	end)

	table.insert(self.osu_skins, {
		name = skin_name,
		path = skin_directory,
		directory_path = skin_directory,
		file_name = file_name,
		format = "osu",
		metadata = {
			name = skin_name,
			author = general.Author,
			version = general.Version,
			gamemode = "mania",
			input_modes = input_modes,
		},
		skin_ini = skin_ini,
	})
end

---osu! only recognizes a skin.ini in each skin directory's root. Match the
---filename without regard to case, since the game normally runs on Windows.
---@param directory_path string
function SkinRegistry:scanOsu(directory_path)
	local directories = self.fs:getDirectoryItems(directory_path)
	table.sort(directories)
	for _, name in ipairs(directories) do
		local skin_directory = path_util.join(directory_path, name)
		local info = self.fs:getInfo(skin_directory)
		if info and info.type == "directory" then
			local files = self.fs:getDirectoryItems(skin_directory)
			table.sort(files)
			for _, file_name in ipairs(files) do
				if file_name:lower() == "skin.ini" then
					local file_info = self.fs:getInfo(path_util.join(skin_directory, file_name))
					if file_info and file_info.type == "file" then
						self:loadOsuSkin(skin_directory, file_name)
						break
					end
				end
			end
		end
	end
end

---@param directory_path string
---@param input_modes string[]?
function SkinRegistry:addStepmaniaDiscovery(directory_path, input_modes)
	local name = directory_path:match("([^/]+)$") or directory_path
	table.insert(self.stepmania_skins, {
		name = name,
		path = directory_path,
		input_modes = input_modes or {"4key"},
	})
end

---@param directory_path string
---@param input_modes string[]?
function SkinRegistry:scanStepmania(directory_path, input_modes)
	local items = self.fs:getDirectoryItems(directory_path)
	table.sort(items)

	-- External skin formats are packages rooted at a directory, not individual
	-- Lua files. Do not execute their scripts while identifying their format.
	for _, name in ipairs(items) do
		local path = path_util.join(directory_path, name)
		local info = self.fs:getInfo(path)
		if info and info.type == "directory" then
			-- StepMania accepts either NoteSkin.lua spelling; Linux does not.
			if self.fs:getInfo(path_util.join(path, "NoteSkin.lua"))
				or self.fs:getInfo(path_util.join(path, "Noteskin.lua"))
				or self.fs:getInfo(path_util.join(path, "metrics.ini")) then
				self:addStepmaniaDiscovery(path, input_modes)
			elseif name ~= "__MACOSX" then
				-- Etterna groups NoteSkins by game type. `common` contains shared
				-- fallback assets, rather than playable skins.
				local game_type_modes = {
					dance = {"4key"},
					kb7 = {"7key"},
					popn = {"9key"},
					pump = {"5key"},
					beat = {"5key", "7key"},
				}
				local keymode = name:match("^%d+key$")
				local modes = game_type_modes[name] or (keymode and {keymode}) or input_modes
				if name ~= "common" then self:scanStepmania(path, modes) end
			end
		elseif info and info.type == "file" and name:lower():match("%.skin%.lua$") then
			self:loadFile(path)
		end
	end
end

---@param directory_path string
function SkinRegistry:scan(directory_path)
	for _, name in ipairs(self.fs:getDirectoryItems(directory_path)) do
		local path = path_util.join(directory_path, name)
		local info = self.fs:getInfo(path)
		if info and info.type == "directory" then
			self:scan(path)
		elseif info and info.type == "file" and name:lower():match("%.skin%.lua$") then
			self:loadFile(path)
		end
	end
end

---Discovers metadata only. Expensive renderer resources stay deferred in SkinInfo.load.
function SkinRegistry:load()
	self.skins = {}
	self.stepmania_skins = {}
	self.osu_skins = {}
	self.errors = {}
	if self.fs:getInfo(self.skins_rizu_path) then
		self:scan(self.skins_rizu_path)
	end
	if self.fs:getInfo(self.skins_stepmania_path) then
		self:scanStepmania(self.skins_stepmania_path)
	end
	if self.fs:getInfo(self.skins_osu_path) then
		self:scanOsu(self.skins_osu_path)
	end
	self:scan(self.base_path)
	table.sort(self.skins, function(a, b)
		return a.path < b.path
	end)
	table.sort(self.osu_skins, function(a, b)
		return a.path < b.path
	end)
end

---@return rizu.skin.SkinInfo[]
function SkinRegistry:getSkins()
	return self.skins
end

---Discovered package paths are exposed separately and are not loadable skins.
---@return rizu.skin.StepmaniaSkinDiscovery[]
function SkinRegistry:getStepmaniaSkins()
	return self.stepmania_skins
end

---Discovered osu! skin metadata and parsed ini files; rendering support is separate.
---@return rizu.skin.OsuSkinDiscovery[]
function SkinRegistry:getOsuSkins()
	return self.osu_skins
end

---@param path string
---@return rizu.skin.OsuSkinDiscovery?
function SkinRegistry:getOsuSkin(path)
	for _, skin in ipairs(self.osu_skins) do
		if skin.path == path then
			return skin
		end
	end
end

---@param path string
---@return rizu.skin.SkinInfo?
function SkinRegistry:getSkin(path)
	for _, skin in ipairs(self.skins) do
		if skin.path == path then
			return skin
		end
	end
end

---@param gamemode string
---@param input_mode string
---@param name string?
---@return rizu.skin.SkinInfo?
function SkinRegistry:getSkinForInputMode(gamemode, input_mode, name)
	-- Configured skin paths commonly come from directory pickers, which retain
	-- a trailing slash unlike registry paths.
	if name then
		name = name:gsub("/+$", "")
	end
	local fallback
	for _, skin in ipairs(self.skins) do
		local metadata = skin.metadata
		if metadata and metadata.gamemode == gamemode then
			for _, supported_input_mode in ipairs(metadata.input_modes) do
				if supported_input_mode == input_mode then
					if name and (skin.path == name or metadata.name == name) then return skin end
					fallback = fallback or skin
				elseif supported_input_mode == "any" then
					fallback = fallback or skin
				end
			end
		end
	end
	return fallback
end

return SkinRegistry
