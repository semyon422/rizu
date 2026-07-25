local class = require("class")
local Observable = require("Observable")
local json = require("json")

---@class rizu.config.Config
---@operator call: rizu.config.Config
---@field persistent_values {[rizu.config.Setting]: any}
---@field transient_values {[rizu.config.Setting]: any}
---@field settings_map {[rizu.config.Setting]: boolean}
---@field path_to_setting {[string]: rizu.config.Setting}
---@field setting_to_path {[rizu.config.Setting]: string}
---@field onChanged util.Observable
local Config = class()

---@param node rizu.config.Setting | {[string]: rizu.config.Setting}
---@param path string
---@param settings_map {[rizu.config.Setting]: boolean}
---@param path_to_setting {[string]: rizu.config.Setting}
---@param setting_to_path {[rizu.config.Setting]: string}
local function walk_schema(node, path, settings_map, path_to_setting, setting_to_path)
	for key, child in pairs(node) do
		local current_path = path == "" and key or (path .. "." .. key)
		if type(child) == "table" then
			if child.kind then
				settings_map[child] = true
				path_to_setting[current_path] = child
				setting_to_path[child] = current_path
			else
				walk_schema(child, current_path, settings_map, path_to_setting, setting_to_path)
			end
		end
	end
end

---@param schema table
function Config:new(schema)
	assert(schema, "Schema is required")
	self.persistent_values = {}
	self.transient_values = {}
	self.settings_map = {}
	self.path_to_setting = {}
	self.setting_to_path = {}
	self.onChanged = Observable()

	walk_schema(schema, "", self.settings_map, self.path_to_setting, self.setting_to_path)
end

---@param setting rizu.config.Setting
---@return any
function Config:get(setting)
	local val = self.transient_values[setting]
	if val ~= nil then
		return val
	end
	val = self.persistent_values[setting]
	if val ~= nil then
		return val
	end
	return setting.default_value
end

---@param setting rizu.config.Setting
---@return boolean?
function Config:getBoolean(setting)
	assert(setting and setting.kind == "checkbox", "getBoolean only accepts Checkbox settings")
	local v = self:get(setting)
	if v == nil then return nil end
	return not not v
end

---@param setting rizu.config.Setting
---@return string?
function Config:getString(setting)
	assert(
		setting and (setting.kind == "textbox" or setting.kind == "choice"),
		"getString only accepts Textbox and Choice settings"
	)
	local v = self:get(setting)
	if v == nil then return nil end
	return tostring(v)
end

---@param setting rizu.config.Setting
---@return number?
function Config:getNumber(setting)
	assert(setting and setting.kind == "range", "getNumber only accepts Range settings")
	local v = self:get(setting)
	if v == nil then return nil end
	return tonumber(v)
end

---@param setting rizu.config.Setting
---@param value any
function Config:set(setting, value)
	local is_deferred = setting.is_deferred

	if is_deferred then
		if self.transient_values[setting] == value then
			return
		end
		self.transient_values[setting] = value
	else
		if self.persistent_values[setting] == value then
			return
		end
		self.persistent_values[setting] = value
		self.onChanged:send(setting)
	end
end

---@param setting rizu.config.Setting
---@param value boolean
function Config:setBoolean(setting, value)
	assert(setting and setting.kind == "checkbox", "setBoolean only accepts Checkbox settings")
	assert(type(value) == "boolean", "value must be a boolean")
	self:set(setting, value)
end

---@param setting rizu.config.Setting
---@param value string
function Config:setString(setting, value)
	assert(
		setting and (setting.kind == "textbox" or setting.kind == "choice"),
		"setString only accepts Textbox and Choice settings"
	)
	assert(type(value) == "string", "value must be a string")
	self:set(setting, value)
end

---@param setting rizu.config.Setting
---@param value number
function Config:setNumber(setting, value)
	assert(setting and setting.kind == "range", "setNumber only accepts Range settings")
	assert(type(value) == "number", "value must be a number")
	self:set(setting, value)
end

function Config:commit()
	local updated_settings = {} ---@type rizu.config.Setting[]
	for setting, value in pairs(self.transient_values) do
		if self.persistent_values[setting] ~= value then
			self.persistent_values[setting] = value
			table.insert(updated_settings, setting)
		end
	end
	self.transient_values = {}

	if #updated_settings > 0 then
		for _, setting in ipairs(updated_settings) do
			self.onChanged:send(setting)
		end
	end
end

function Config:discard()
	self.transient_values = {}
end

---@return string json
function Config:serialize()
	local data = {} ---@type {[string]: any}
	for setting, value in pairs(self.persistent_values) do
		local path = self.setting_to_path[setting]
		if path then
			data[path] = value
		end
	end
	return json.encode(data, {indent = "\t"}) .. "\n"
end

---@param json_str string
---@return boolean success
function Config:deserialize(json_str)
	---@type boolean, {[string]: any}
	local ok, data = pcall(json.decode, json_str)
	if not ok or type(data) ~= "table" then
		return false
	end
	for path, value in pairs(data) do
		local setting = self.path_to_setting[path]
		if setting then
			self.persistent_values[setting] = value
		end
	end
	return true
end

return Config
