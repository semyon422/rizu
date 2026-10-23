local class = require("class")
local SkinConfigSerializer = require("rizu.skin.SkinConfigSerializer")

---@alias rizu.skin.SkinConfigValue number|string|boolean
---@alias rizu.skin.SkinConfigPropertyOverrides {[string]: rizu.skin.SkinConfigValue}
---@alias rizu.skin.SkinConfigInputModeOverrides {[string]: rizu.skin.SkinConfigPropertyOverrides}
---@alias rizu.skin.SkinConfigOverrides {[string]: rizu.skin.SkinConfigInputModeOverrides}

---@class rizu.skin.SkinConfig
---@operator call: rizu.skin.SkinConfig
---@field private values rizu.skin.SkinConfigOverrides
---@field private huds rizu.skin.SkinConfigHuds
---@field has_unsaved_changes boolean
local SkinConfig = class()

---@param values? rizu.skin.SkinConfigOverrides
function SkinConfig:new(values)
	self.values = {}
	self.huds = {}
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
	local mode_values = self.values[gamemode]
	local input_values = mode_values and mode_values[input_mode]
	local value = input_values and input_values[key]
	if value == nil then return default end
	return value
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
end

---The HUD layout the player saved, nil when the skin's default layout is used.
---@param gamemode string
---@param input_mode string
---@return rizu.skin.SkinConfigHudLayout?
function SkinConfig:getHud(gamemode, input_mode)
	local modes = self.huds[gamemode]
	-- A copy, so callers cannot mutate config state without setHud().
	return SkinConfigSerializer.sanitizeHud(modes and modes[input_mode])
end

---@param gamemode string
---@param input_mode string
---@param layout rizu.skin.SkinConfigHudLayout? nil goes back to the skin's default layout.
function SkinConfig:setHud(gamemode, input_mode, layout)
	assert(type(gamemode) == "string" and gamemode ~= "", "gamemode must be a non-empty string")
	assert(type(input_mode) == "string" and input_mode ~= "", "input_mode must be a non-empty string")
	assert(layout == nil or type(layout) == "table", "hud layout must be a table or nil")
	local modes = self.huds[gamemode] or {}
	self.huds[gamemode] = modes
	modes[input_mode] = SkinConfigSerializer.sanitizeHud(layout)
	if next(modes) == nil then self.huds[gamemode] = nil end
	self.has_unsaved_changes = true
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

	self.values = replacement
end

---@return string
function SkinConfig:serialize()
	return SkinConfigSerializer.serialize(self.values, self.huds)
end

---@param content string
---@return boolean success
---@return string? error_message
function SkinConfig:deserialize(content)
	local overrides, deserialize_error, huds = SkinConfigSerializer.deserialize(content)
	if not overrides then
		return false, deserialize_error
	end
	self:replaceOverrides(overrides)
	self.huds = huds or {}
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
