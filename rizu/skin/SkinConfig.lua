local class = require("class")
local SkinConfigSerializer = require("rizu.skin.SkinConfigSerializer")

---@alias rizu.skin.SkinConfigValue number|string|boolean
---@alias rizu.skin.SkinConfigPropertyOverrides {[string]: rizu.skin.SkinConfigValue}
---@alias rizu.skin.SkinConfigInputModeOverrides {[string]: rizu.skin.SkinConfigPropertyOverrides}
---@alias rizu.skin.SkinConfigOverrides {[string]: rizu.skin.SkinConfigInputModeOverrides}
---@alias rizu.skin.SkinConfigChangeCallback fun(value: rizu.skin.SkinConfigValue?, old_value: rizu.skin.SkinConfigValue?, gamemode: string, input_mode: string, key: string)

---@class rizu.skin.SkinConfig
---@operator call: rizu.skin.SkinConfig
---@field private values rizu.skin.SkinConfigOverrides
---@field private subscriptions {[string]: {[string]: {[string]: {[rizu.skin.SkinConfigChangeCallback]: boolean}}}}
---@field private all_subscriptions {[rizu.skin.SkinConfigChangeCallback]: boolean}
---@field has_unsaved_changes boolean
local SkinConfig = class()

---@param values? rizu.skin.SkinConfigOverrides
function SkinConfig:new(values)
	self.values = {}
	self.subscriptions = {}
	self.all_subscriptions = {}
	self.has_unsaved_changes = false
	if values then
		self:replaceOverrides(values)
	end
end

---@param gamemode string
---@param input_mode string
---@param key string
---@param default? rizu.skin.SkinConfigValue
---@return rizu.skin.SkinConfigValue?
function SkinConfig:get(gamemode, input_mode, key, default)
	local value = self:getOverride(gamemode, input_mode, key)
	if value == nil then return default end
	return value
end

---@param gamemode string
---@param input_mode string
---@param key string
---@return rizu.skin.SkinConfigValue?
function SkinConfig:getOverride(gamemode, input_mode, key)
	local mode_values = self.values[gamemode]
	local input_values = mode_values and mode_values[input_mode]
	return input_values and input_values[key]
end

---@param gamemode string
---@param input_mode string
---@param key string
---@param value rizu.skin.SkinConfigValue?
function SkinConfig:set(gamemode, input_mode, key, value)
	assert(type(gamemode) == "string" and gamemode ~= "", "gamemode must be a non-empty string")
	assert(type(input_mode) == "string" and input_mode ~= "", "input_mode must be a non-empty string")
	assert(type(key) == "string" and key ~= "", "key must be a non-empty string")
	assert(value == nil or type(value) == "number" or type(value) == "string" or type(value) == "boolean",
		"value must be a number, string, boolean, or nil")
	if type(value) == "number" then
		assert(value == value and value ~= math.huge and value ~= -math.huge, "value must be finite")
	end

	local mode_values = self.values[gamemode]
	local input_values = mode_values and mode_values[input_mode]
	local old_value = input_values and input_values[key]
	if old_value == value then return end
	self.has_unsaved_changes = true

	if value == nil then
		if input_values then
			input_values[key] = nil
			if next(input_values) == nil then mode_values[input_mode] = nil end
			if next(mode_values) == nil then self.values[gamemode] = nil end
		end
	else
		mode_values = mode_values or {}
		input_values = input_values or {}
		self.values[gamemode] = mode_values
		mode_values[input_mode] = input_values
		input_values[key] = value
	end

	self:notify(gamemode, input_mode, key, value, old_value)
end

---@param gamemode string
---@param input_mode string
---@param key string
---@param callback rizu.skin.SkinConfigChangeCallback
---@return fun() unsubscribe
function SkinConfig:subscribe(gamemode, input_mode, key, callback)
	assert(type(callback) == "function", "callback must be a function")
	local modes = self.subscriptions[gamemode]
	if not modes then
		modes = {}
		self.subscriptions[gamemode] = modes
	end
	local input_modes = modes[input_mode]
	if not input_modes then
		input_modes = {}
		modes[input_mode] = input_modes
	end
	local keys = input_modes[key]
	if not keys then
		keys = {}
		input_modes[key] = keys
	end
	keys[callback] = true
	return function()
		keys[callback] = nil
	end
end

---@param callback rizu.skin.SkinConfigChangeCallback
---@return fun() unsubscribe
function SkinConfig:subscribeAll(callback)
	assert(type(callback) == "function", "callback must be a function")
	self.all_subscriptions[callback] = true
	return function()
		self.all_subscriptions[callback] = nil
	end
end

---@param gamemode string
---@param input_mode string
---@param key string
---@param value rizu.skin.SkinConfigValue?
---@param old_value rizu.skin.SkinConfigValue?
function SkinConfig:notify(gamemode, input_mode, key, value, old_value)
	local callbacks = {} ---@type rizu.skin.SkinConfigChangeCallback[]
	local modes = self.subscriptions[gamemode]
	local input_modes = modes and modes[input_mode]
	local keys = input_modes and input_modes[key]
	for callback in pairs(keys or {}) do
		callbacks[#callbacks + 1] = callback
	end
	for callback in pairs(self.all_subscriptions) do
		callbacks[#callbacks + 1] = callback
	end
	for _, callback in ipairs(callbacks) do
		callback(value, old_value, gamemode, input_mode, key)
	end
end

---@param overrides rizu.skin.SkinConfigOverrides
function SkinConfig:replaceOverrides(overrides)
	assert(type(overrides) == "table", "overrides must be a table")
	local replacement = {} ---@type rizu.skin.SkinConfigOverrides
	for gamemode, modes in pairs(overrides) do
		assert(type(gamemode) == "string" and gamemode ~= "", "gamemode must be a non-empty string")
		assert(type(modes) == "table", "gamemode overrides must be tables")
		for input_mode, keys in pairs(modes) do
			assert(type(input_mode) == "string" and input_mode ~= "", "input_mode must be a non-empty string")
			assert(type(keys) == "table", "input mode overrides must be tables")
			for key, value in pairs(keys) do
				assert(type(key) == "string" and key ~= "", "property keys must be non-empty strings")
				assert(type(value) == "number" or type(value) == "string" or type(value) == "boolean",
					"override values must be numbers, strings, or booleans")
				if type(value) == "number" then
					assert(value == value and value ~= math.huge and value ~= -math.huge, "override numbers must be finite")
				end
			end
		end
	end

	-- Copy the input so callers cannot mutate config state without set().
	for gamemode, modes in pairs(overrides) do
		local copied_modes = {} ---@type rizu.skin.SkinConfigInputModeOverrides
		for input_mode, keys in pairs(modes) do
			local copied_keys = {} ---@type rizu.skin.SkinConfigPropertyOverrides
			for key, value in pairs(keys) do copied_keys[key] = value end
			copied_modes[input_mode] = copied_keys
		end
		replacement[gamemode] = copied_modes
	end

	local old_values = self.values
	local had_unsaved_changes = self.has_unsaved_changes
	self.values = replacement
	self.has_unsaved_changes = false
	for gamemode, modes in pairs(old_values) do
		for input_mode, keys in pairs(modes) do
			for key, old_value in pairs(keys) do
				local new_modes = replacement[gamemode]
				local new_keys = new_modes and new_modes[input_mode]
				local new_value = new_keys and new_keys[key]
				if old_value ~= new_value then
					self:notify(gamemode, input_mode, key, new_value, old_value)
				end
			end
		end
	end
	for gamemode, modes in pairs(replacement) do
		for input_mode, keys in pairs(modes) do
			for key, value in pairs(keys) do
				local old_modes = old_values[gamemode]
				local old_keys = old_modes and old_modes[input_mode]
				if not old_keys or old_keys[key] == nil then
					self:notify(gamemode, input_mode, key, value, nil)
				end
			end
		end
	end
	self.has_unsaved_changes = had_unsaved_changes
end

---@return rizu.skin.SkinConfigOverrides
function SkinConfig:getOverrides()
	local copy = {} ---@type rizu.skin.SkinConfigOverrides
	for gamemode, modes in pairs(self.values) do
		local copied_modes = {} ---@type rizu.skin.SkinConfigInputModeOverrides
		for input_mode, keys in pairs(modes) do
			local copied_keys = {} ---@type rizu.skin.SkinConfigPropertyOverrides
			for key, value in pairs(keys) do copied_keys[key] = value end
			copied_modes[input_mode] = copied_keys
		end
		copy[gamemode] = copied_modes
	end
	return copy
end

---@return string
function SkinConfig:serialize()
	return SkinConfigSerializer.serialize(self.values)
end

---@param content string
---@return boolean success
---@return string? error_message
function SkinConfig:deserialize(content)
	local overrides, deserialize_error = SkinConfigSerializer.deserialize(content)
	if not overrides then
		return false, deserialize_error
	end
	self:replaceOverrides(overrides)
	return true
end

---@param fs fs.IFilesystem
---@param path string
---@return boolean success
---@return string? error_message
function SkinConfig:load(fs, path)
	assert(fs and type(fs.read) == "function", "filesystem is required")
	assert(type(path) == "string" and path ~= "", "skin config path must be a non-empty string")
	local content, read_error = fs:read(path)
	if not content then
		return false, read_error or "could not read skin config"
	end
	local loaded, deserialize_error = self:deserialize(content)
	if loaded then
		self.has_unsaved_changes = false
	end
	return loaded, deserialize_error
end

---@param fs fs.IFilesystem
---@param path string
---@return boolean success
---@return string? error_message
function SkinConfig:save(fs, path)
	assert(fs and type(fs.write) == "function", "filesystem is required")
	assert(type(path) == "string" and path ~= "", "skin config path must be a non-empty string")
	local directory = path:match("^(.*)/[^/]+$")
	if directory and directory ~= "" and not fs:getInfo(directory) then
		local created, create_error = fs:createDirectory(directory)
		if not created and not fs:getInfo(directory) then
			return false, create_error or "could not create skin config directory"
		end
	end
	local written, write_error = fs:write(path, self:serialize())
	if not written then
		return false, write_error or "could not write skin config"
	end
	self.has_unsaved_changes = false
	return true
end

return SkinConfig
