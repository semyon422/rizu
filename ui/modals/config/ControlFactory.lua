local Checkbox = require("ui.views.form.Checkbox")
local Dropdown = require("ui.views.form.Dropdown")
local LegacyBinding = require("ui.modals.config.LegacyBinding")
local Slider = require("ui.views.form.Slider")
local Textbox = require("ui.views.form.Textbox")

---@class ui.modals.config.ControlMetadata
---@field name string
---@field keywords string[]?
---@field tip string?

---@class ui.modals.config.BooleanControl : ui.modals.config.ControlMetadata
---@field on_change (fun(value: boolean))?

---@class ui.modals.config.NumberControl : ui.modals.config.ControlMetadata
---@field min number
---@field max number
---@field step number?
---@field value_format (fun(value: number): string)?
---@field from_storage (fun(value: number): number)?
---@field to_storage (fun(value: number): number)?
---@field on_change (fun(value: number))?

---@class ui.modals.config.ChoiceControl : ui.modals.config.ControlMetadata
---@field options any[]?
---@field width number?
---@field format (fun(value: any): string)?
---@field on_change (fun(value: any))?

local ControlFactory = {}

local WIDTH = 635

---@param control ui.views.form.FormControl
---@param metadata ui.modals.config.ControlMetadata
---@param key string
---@return ui.views.form.FormControl control
local function configure(control, metadata, key)
	control:setSettingMetadata(metadata.name, metadata.keywords, metadata.tip, key)
	return control
end

---@param config rizu.config.Config
---@param key string
---@param metadata ui.modals.config.ControlMetadata
---@return ui.views.form.Checkbox
function ControlFactory.boolean(config, key, metadata)
	local control = Checkbox({
		text = metadata.name,
		checked = config:getBoolean(key),
		on_change = function(value)
			config:setBoolean(key, value)
		end,
	})
	return configure(control, metadata, key) --[[@as ui.views.form.Checkbox]]
end

---@param config rizu.config.Config
---@param key string
---@param metadata ui.modals.config.NumberControl
---@return ui.views.form.Slider
function ControlFactory.number(config, key, metadata)
	local control = Slider({
		label = metadata.name,
		value = config:getNumber(key),
		min = metadata.min,
		max = metadata.max,
		step = metadata.step,
		width = WIDTH,
		value_format = metadata.value_format,
		on_change = function(value)
			config:setNumber(key, value)
		end,
	})
	return configure(control, metadata, key) --[[@as ui.views.form.Slider]]
end

---@param config rizu.config.Config
---@param key string
---@param metadata ui.modals.config.ControlMetadata
---@return ui.views.form.Dropdown
function ControlFactory.choice(config, key, metadata)
	local control = Dropdown({
		label = metadata.name,
		options = config:getChoices(key),
		value = config:getChoice(key),
		width = WIDTH,
		on_change = function(value)
			config:setChoice(key, value)
		end,
	})
	return configure(control, metadata, key) --[[@as ui.views.form.Dropdown]]
end

---@param config rizu.config.Config
---@param key string
---@param metadata ui.modals.config.ControlMetadata
---@return ui.views.form.Textbox
function ControlFactory.string(config, key, metadata)
	local control = Textbox({
		label = metadata.name,
		text = config:getString(key),
		width = WIDTH,
		on_change = function(value)
			config:setString(key, value)
		end,
	})
	return configure(control, metadata, key) --[[@as ui.views.form.Textbox]]
end

---@param settings table
---@param path string[]
---@param metadata ui.modals.config.BooleanControl
---@return ui.views.form.Checkbox
function ControlFactory.legacyBoolean(settings, path, metadata)
	local parent, key = LegacyBinding.resolve(settings, path)
	local setting_key = LegacyBinding.key(path)
	local value = parent[key]
	assert(type(value) == "boolean", "legacy setting must be a boolean: " .. setting_key)
	local control = Checkbox({
		text = metadata.name,
		checked = value,
		on_change = function(new_value)
			parent[key] = new_value
			if metadata.on_change then
				metadata.on_change(new_value)
			end
		end,
	})
	return configure(control, metadata, setting_key) --[[@as ui.views.form.Checkbox]]
end

---@param settings table
---@param path string[]
---@param metadata ui.modals.config.NumberControl
---@return ui.views.form.Slider
function ControlFactory.legacyNumber(settings, path, metadata)
	local parent, key = LegacyBinding.resolve(settings, path)
	local setting_key = LegacyBinding.key(path)
	local value = assert(parent[key], "unknown legacy setting: " .. setting_key)
	assert(type(value) == "number", "legacy setting must be a number: " .. setting_key)
	if metadata.from_storage then
		value = metadata.from_storage(value)
	end
	local control = Slider({
		label = metadata.name,
		value = value,
		min = metadata.min,
		max = metadata.max,
		step = metadata.step,
		width = WIDTH,
		value_format = metadata.value_format,
		on_change = function(new_value)
			parent[key] = metadata.to_storage and metadata.to_storage(new_value) or new_value
			if metadata.on_change then
				metadata.on_change(new_value)
			end
		end,
	})
	return configure(control, metadata, setting_key) --[[@as ui.views.form.Slider]]
end

---@param settings table
---@param path string[]
---@param metadata ui.modals.config.ChoiceControl
---@return ui.views.form.Dropdown
function ControlFactory.legacyChoice(settings, path, metadata)
	local parent, key = LegacyBinding.resolve(settings, path)
	local setting_key = LegacyBinding.key(path)
	local value = parent[key]
	assert(value ~= nil, "unknown legacy setting: " .. setting_key)
	local control = Dropdown({
		label = metadata.name,
		options = assert(metadata.options, "legacy choice options are required"),
		value = value,
		width = metadata.width or WIDTH,
		format = metadata.format,
		on_change = function(new_value)
			parent[key] = new_value
			if metadata.on_change then
				metadata.on_change(new_value)
			end
		end,
	})
	return configure(control, metadata, setting_key) --[[@as ui.views.form.Dropdown]]
end

return ControlFactory
