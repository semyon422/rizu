local class = require("class")
local json = require("json")

---@class rizu.config.KeyBinding
---@field key string
---@field control boolean?
---@field shift boolean?
---@field alt boolean?
---@field super boolean?
---@field allow_repeat boolean?

---@alias rizu.config.KeyBindings rizu.config.KeyBinding[]
---@alias rizu.config.Kind "number"|"choice"|"boolean"|"string"|"key_bindings"
---@alias rizu.config.Value number|string|boolean|rizu.config.KeyBindings
---@alias rizu.config.ChangeCallback fun(value: rizu.config.Value, old_value: rizu.config.Value, key: string)
---@alias rizu.config.NumberChangeCallback fun(value: number, old_value: number, key: string)
---@alias rizu.config.StringChangeCallback fun(value: string, old_value: string, key: string)
---@alias rizu.config.BooleanChangeCallback fun(value: boolean, old_value: boolean, key: string)
---@alias rizu.config.KeyBindingsChangeCallback fun(value: rizu.config.KeyBindings, old_value: rizu.config.KeyBindings, key: string)

---@class rizu.config.Definition
---@field kind rizu.config.Kind
---@field default rizu.config.Value
---@field choices string[]?
---@field min number? Minimum value for number definitions.
---@field max number? Maximum value for number definitions.
---@field step number? Increment used when editing number definitions.

---@class rizu.config.Config
---@overload fun(fs: fs.IFilesystem, path: string): rizu.config.Config
---@field fs fs.IFilesystem
---@field path string
---@field values {[string]: rizu.config.Value}
---@field definitions {[string]: rizu.config.Definition}
---@field private subscriptions {[string]: {[rizu.config.ChangeCallback]: boolean}}
---@field private all_subscriptions {[rizu.config.ChangeCallback]: boolean}
local Config = class()

---@param filesystem fs.IFilesystem
---@param path string
function Config:new(filesystem, path)
	self.fs = assert(filesystem, "filesystem is required")
	self.path = assert(path, "path is required")
	self.values = {}
	self.definitions = {}
	self.subscriptions = {}
	self.all_subscriptions = {}
end

---@param kind rizu.config.Kind
---@return "number"|"string"|"boolean"
local function lua_type(kind)
	if kind == "choice" then
		return "string"
	elseif kind == "key_bindings" then
		return "table"
	else
		---@cast kind "number"|"string"|"boolean"
		return kind
	end
end

---@param bindings rizu.config.KeyBindings
---@return rizu.config.KeyBindings
local function copy_key_bindings(bindings)
	local copy = {}
	for i, binding in ipairs(bindings) do
		copy[i] = {
			key = binding.key,
			control = binding.control,
			shift = binding.shift,
			alt = binding.alt,
			super = binding.super,
			allow_repeat = binding.allow_repeat,
		}
	end
	return copy
end

---@param bindings rizu.config.KeyBindings
local function validate_key_bindings(bindings)
	for index, binding in ipairs(bindings) do
		assert(type(binding) == "table", "key binding must be a table at index " .. index)
		assert(type(binding.key) == "string" and binding.key ~= "", "key binding key must be a non-empty string")
		for _, modifier in ipairs({"control", "shift", "alt", "super", "allow_repeat"}) do
			assert(binding[modifier] == nil or type(binding[modifier]) == "boolean", modifier .. " must be a boolean")
		end
	end
end

---@param a rizu.config.KeyBindings
---@param b rizu.config.KeyBindings
---@return boolean
local function key_bindings_equal(a, b)
	if #a ~= #b then return false end
	for i, binding in ipairs(a) do
		local other = b[i]
		if not other or binding.key ~= other.key
			or (binding.control == true) ~= (other.control == true)
			or (binding.shift == true) ~= (other.shift == true)
			or (binding.alt == true) ~= (other.alt == true)
			or (binding.super == true) ~= (other.super == true)
			or (binding.allow_repeat == true) ~= (other.allow_repeat == true)
		then return false end
	end
	return true
end

---@param key string
---@param definition rizu.config.Definition
local function validate_default(key, definition)
	assert(type(key) == "string" and key ~= "", "key must be a non-empty string")
	assert(type(definition.default) == lua_type(definition.kind), "default has the wrong type")
	if definition.kind == "number" then
		assert(type(definition.min) == "number", "number min is required")
		assert(type(definition.max) == "number", "number max is required")
		assert(type(definition.step) == "number" and definition.step > 0, "number step must be positive")
		assert(definition.min <= definition.max, "number min must not exceed max")
		assert(definition.default >= definition.min and definition.default <= definition.max, "number default is out of range")
	elseif definition.kind == "key_bindings" then
		validate_key_bindings(definition.default --[[@as rizu.config.KeyBindings]])
	elseif definition.kind == "choice" then
		assert(definition.choices and #definition.choices > 0, "choices must not be empty")
		local found = false
		for _, choice in ipairs(definition.choices) do
			assert(type(choice) == "string", "choices must contain strings")
			found = found or choice == definition.default
		end
		assert(found, "default must be one of the choices")
	end
end

---@param key string
---@param definition rizu.config.Definition
function Config:setDefault(key, definition)
	if self.definitions[key] then
		error("default is already defined for " .. key)
	end
	validate_default(key, definition)
	self.definitions[key] = definition
end

---@param key string
---@param default number
---@param min? number
---@param max? number
---@param step? number
function Config:setDefaultNumber(key, default, min, max, step)
	self:setDefault(key, {
		kind = "number",
		default = default,
		min = min or -math.huge,
		max = max or math.huge,
		step = step or 1,
	})
end

---@param key string
---@param default string
---@param choices string[]
function Config:setDefaultChoice(key, default, choices)
	self:setDefault(key, {kind = "choice", default = default, choices = choices})
end

---@param key string
---@param default boolean
function Config:setDefaultBoolean(key, default)
	self:setDefault(key, {kind = "boolean", default = default})
end

---@param key string
---@param default string
function Config:setDefaultString(key, default)
	self:setDefault(key, {kind = "string", default = default})
end

---@param key string
---@param default rizu.config.KeyBindings
function Config:setDefaultKeyBindings(key, default)
	validate_key_bindings(default)
	self:setDefault(key, {kind = "key_bindings", default = copy_key_bindings(default)})
end

---@param key string
---@return rizu.config.Definition
function Config:getDefinition(key)
	local definition = self.definitions[key]
	if not definition then
		error("unknown config key: " .. tostring(key))
	end
	return definition
end

---@param key string
---@return rizu.config.Value
function Config:get(key)
	local definition = self:getDefinition(key)
	local value = self.values[key]
	if value ~= nil then
		return value
	end
	return definition.default
end

---@param self rizu.config.Config
---@param key string
---@param kind rizu.config.Kind
---@return rizu.config.Definition
local function assert_kind(self, key, kind)
	local definition = self:getDefinition(key)
	if definition.kind ~= kind then
		error(("config key %s is %s, not %s"):format(key, definition.kind, kind))
	end
	return definition
end

---@param key string
---@return number
function Config:getNumber(key)
	assert_kind(self, key, "number")
	return self:get(key) --[[@as number]]
end

---@param key string
---@return string
function Config:getChoice(key)
	assert_kind(self, key, "choice")
	return self:get(key) --[[@as string]]
end

---@param key string
---@return string[]
function Config:getChoices(key)
	local definition = assert_kind(self, key, "choice")
	return definition.choices
end

---@param key string
---@return boolean
function Config:getBoolean(key)
	assert_kind(self, key, "boolean")
	return self:get(key) --[[@as boolean]]
end

---@param key string
---@return string
function Config:getString(key)
	assert_kind(self, key, "string")
	return self:get(key) --[[@as string]]
end

---@param key string
---@return rizu.config.KeyBindings
function Config:getKeyBindings(key)
	assert_kind(self, key, "key_bindings")
	return copy_key_bindings(self:get(key) --[[@as rizu.config.KeyBindings]])
end

---@param key string
---@param value rizu.config.Value
---@param old_value rizu.config.Value
function Config:notify(key, value, old_value)
	local callbacks = {} ---@type rizu.config.ChangeCallback[]
	for callback in pairs(self.subscriptions[key] or {}) do
		callbacks[#callbacks + 1] = callback
	end
	for callback in pairs(self.all_subscriptions) do
		callbacks[#callbacks + 1] = callback
	end
	local key_bindings = self.definitions[key].kind == "key_bindings"
	for _, callback in ipairs(callbacks) do
		if key_bindings then
			callback(
				copy_key_bindings(value --[[@as rizu.config.KeyBindings]]),
				copy_key_bindings(old_value --[[@as rizu.config.KeyBindings]]),
				key
			)
		else
			callback(value, old_value, key)
		end
	end
end

---@param key string
---@param value rizu.config.Value
function Config:set(key, value)
	local definition = self:getDefinition(key)
	assert(type(value) == lua_type(definition.kind), "value has the wrong type")
	if definition.kind == "number" then
		assert(value >= definition.min and value <= definition.max, "value is out of range")
	elseif definition.kind == "choice" then
		local found = false
		for _, choice in ipairs(definition.choices) do
			found = found or choice == value
		end
		assert(found, "value must be one of the choices")
	elseif definition.kind == "key_bindings" then
		validate_key_bindings(value --[[@as rizu.config.KeyBindings]])
	end

	local old_value = self:get(key)
	local equal = old_value == value
	local is_default = value == definition.default
	if definition.kind == "key_bindings" then
		equal = key_bindings_equal(old_value --[[@as rizu.config.KeyBindings]], value --[[@as rizu.config.KeyBindings]])
		is_default = key_bindings_equal(value --[[@as rizu.config.KeyBindings]], definition.default --[[@as rizu.config.KeyBindings]])
	end
	if equal then return end
	self.values[key] = is_default and nil or value
	self:notify(key, value, old_value)
end

---@param key string
---@param value number
function Config:setNumber(key, value)
	assert_kind(self, key, "number")
	self:set(key, value)
end

---@param key string
---@param value string
function Config:setChoice(key, value)
	assert_kind(self, key, "choice")
	self:set(key, value)
end

---@param key string
---@param value boolean
function Config:setBoolean(key, value)
	assert_kind(self, key, "boolean")
	self:set(key, value)
end

---@param key string
---@param value string
function Config:setString(key, value)
	assert_kind(self, key, "string")
	self:set(key, value)
end

---@param key string
---@param value rizu.config.KeyBindings
function Config:setKeyBindings(key, value)
	assert_kind(self, key, "key_bindings")
	validate_key_bindings(value)
	self:set(key, copy_key_bindings(value))
end

---@param key string
---@param callback rizu.config.ChangeCallback
---@return function unsubscribe
function Config:subscribe(key, callback)
	self:getDefinition(key)
	assert(type(callback) == "function", "callback must be a function")
	local subscriptions = self.subscriptions[key]
	if not subscriptions then
		subscriptions = {}
		self.subscriptions[key] = subscriptions
	end
	subscriptions[callback] = true
	return function()
		subscriptions[callback] = nil
	end
end

---@param key string
---@param callback rizu.config.NumberChangeCallback
---@return function unsubscribe
function Config:subscribeNumber(key, callback)
	assert_kind(self, key, "number")
	return self:subscribe(key, callback --[[@as rizu.config.ChangeCallback]])
end

---@param key string
---@param callback rizu.config.StringChangeCallback
---@return function unsubscribe
function Config:subscribeChoice(key, callback)
	assert_kind(self, key, "choice")
	return self:subscribe(key, callback --[[@as rizu.config.ChangeCallback]])
end

---@param key string
---@param callback rizu.config.BooleanChangeCallback
---@return function unsubscribe
function Config:subscribeBoolean(key, callback)
	assert_kind(self, key, "boolean")
	return self:subscribe(key, callback --[[@as rizu.config.ChangeCallback]])
end

---@param key string
---@param callback rizu.config.StringChangeCallback
---@return function unsubscribe
function Config:subscribeString(key, callback)
	assert_kind(self, key, "string")
	return self:subscribe(key, callback --[[@as rizu.config.ChangeCallback]])
end

---@param key string
---@param callback rizu.config.KeyBindingsChangeCallback
---@return function unsubscribe
function Config:subscribeKeyBindings(key, callback)
	assert_kind(self, key, "key_bindings")
	return self:subscribe(key, callback --[[@as rizu.config.ChangeCallback]])
end

---@param callback rizu.config.ChangeCallback
---@return function unsubscribe
function Config:subscribeAll(callback)
	assert(type(callback) == "function", "callback must be a function")
	self.all_subscriptions[callback] = true
	return function()
		self.all_subscriptions[callback] = nil
	end
end

---@return string json_string
function Config:serialize()
	return json.encode(json.object(self.values), {indent = "\t"}) .. "\n"
end

---@param json_string string
---@return boolean success
function Config:deserialize(json_string)
	local ok, decoded = pcall(json.decode, json_string)
	if not ok or type(decoded) ~= "table" then
		return false
	end
	---@cast decoded {[string]: rizu.config.Value}

	local values = {} ---@type {[string]: rizu.config.Value}
	for key, value in pairs(decoded) do
		local definition = self.definitions[key]
		if definition then
			if type(value) ~= lua_type(definition.kind) then
				return false
			end
			if definition.kind == "number" then
				if value < definition.min or value > definition.max then return false end
			elseif definition.kind == "choice" then
				local found = false
				for _, choice in ipairs(definition.choices) do
					found = found or choice == value
				end
				if not found then return false end
			elseif definition.kind == "key_bindings" then
				local valid = pcall(validate_key_bindings, value)
				if not valid then return false end
			end
			if value ~= definition.default then
				values[key] = value
			end
		end
	end

	local old_values = self.values
	self.values = values
	for key in pairs(self.definitions) do
		local definition = self.definitions[key]
		local old_value = old_values[key] == nil and definition.default or old_values[key]
		local value = values[key] == nil and definition.default or values[key]
		local equal = old_value == value
		if definition.kind == "key_bindings" then
			equal = key_bindings_equal(old_value --[[@as rizu.config.KeyBindings]], value --[[@as rizu.config.KeyBindings]])
		end
		if not equal then self:notify(key, value, old_value) end
	end
	return true
end

---@return boolean success
function Config:load()
	if not self.fs:getInfo(self.path) then
		return false
	end
	local content = self.fs:read(self.path)
	if not content then
		return false
	end
	return self:deserialize(content)
end

---@return boolean success
function Config:save()
	local ok = self.fs:write(self.path, self:serialize())
	return not not ok
end

return Config
