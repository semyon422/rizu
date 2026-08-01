local Checkbox = require("ui.views.form.Checkbox")
local Dropdown = require("ui.views.form.Dropdown")
local Slider = require("ui.views.form.Slider")
local Textbox = require("ui.views.form.Textbox")

---@class ui.modals.config.ControlMetadata
---@field name string
---@field keywords string[]?
---@field tip string?

---@class ui.modals.config.NumberControl : ui.modals.config.ControlMetadata
---@field min number
---@field max number
---@field step number?
---@field width number?

local ControlFactory = {}

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
		width = metadata.width,
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
		width = 780,
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
		width = 780,
		on_change = function(value)
			config:setString(key, value)
		end,
	})
	return configure(control, metadata, key) --[[@as ui.views.form.Textbox]]
end

return ControlFactory
