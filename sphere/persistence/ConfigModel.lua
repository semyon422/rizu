local class = require("class")
local stbl = require("stbl")

---@class sphere.Configs
---@field ai sphere.AiConfig
---@field needle sphere.NeedleConfig
---@field files sphere.FilesConfig
---@field filters sphere.FiltersConfig
---@field input sphere.InputConfig
---@field judgements sphere.JudgementsConfig
---@field online sphere.OnlineConfig
---@field play sphere.PlayConfig
---@field select sphere.SelectConfig
---@field settings sphere.SettingsConfig
---@field urls sphere.UrlsConfig

---@class sphere.ConfigModel
---@operator call: sphere.ConfigModel
---@field configs sphere.Configs
local ConfigModel = class()

ConfigModel.userdataPath = "userdata"
ConfigModel.configModelPath = "sphere/persistence/ConfigModel"

function ConfigModel:new()
	self.configs = {}
	self.openedConfigs = {}
end

---@param name string
---@param mode boolean?
function ConfigModel:open(name, mode)
	self.openedConfigs[name] = mode == true
end

---@param src table
---@param dst table
local function copyTable(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then
				dst[k] = {}
			end
			copyTable(v, dst[k])
		else
			dst[k] = v
		end
	end
end

---@param name string
---@param default_path string?
function ConfigModel:_read(name, default_path)
	local configs = self.configs
	configs[name] = {}
	local config = configs[name]

	local path = self.userdataPath .. "/" .. name .. ".lua"

	if default_path then
		default_path = default_path .. "/" .. name .. ".lua"
	else
		default_path = self.configModelPath .. "/" .. name .. ".lua"
	end

	copyTable(self:readFile(default_path), config)

	local c = self:readFile(path)
	if type(c) == "table" then
		copyTable(c, config)
	elseif type(c) == "function" then
		c(config)
	end
end

---@param specific_name string?
---@param default_path string?
function ConfigModel:read(specific_name, default_path)
	if specific_name then
		self:_read(specific_name, default_path)
		return
	end

	for name in pairs(self.openedConfigs) do
		self:_read(name)
	end
end

---@param name string
---@return boolean
function ConfigModel:_write(name)
	local config = assert(self.configs[name])
	local path = self.userdataPath .. "/" .. name .. ".lua"
	return self:writeFile(path, config)
end

function ConfigModel:write()
	for name, writable in pairs(self.openedConfigs) do
		if writable then
			self:_write(name)
		end
	end
end

---@param path string
---@return any?
function ConfigModel:readFile(path)
	local info = love.filesystem.getInfo(path)
	if not info or info.size == 0 then
		return {}
	end

	return love.filesystem.load(path)()
end

---@param path string
---@param config table
---@return boolean
function ConfigModel:writeFile(path, config)
	return assert(love.filesystem.write(path, ("return %s\n"):format(stbl.encode(config))))
end

return ConfigModel
