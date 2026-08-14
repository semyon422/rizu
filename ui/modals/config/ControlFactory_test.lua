local ControlFactory = require("ui.modals.config.ControlFactory")
local Config = require("rizu.config.Config")
local FakeFilesystem = require("fs.FakeFilesystem")
local Resources = require("ui.Resources")

local test = {}

local textbox_cap = {
	getWidth = function() return 10 end,
}

Resources.sprites = {
	checkbox_body = {getHeight = function() return 20 end},
	checkbox_mark = {},
	form_element_cap_left = textbox_cap,
	form_element_cap_middle = textbox_cap,
	form_element_cap_right = textbox_cap,
}

---@param t testing.T
function test.boolean_binds_ui_config_and_metadata(t)
	local config = Config(FakeFilesystem(), "ui.json")
	config:setDefaultBoolean("show_fps", false)
	local control = ControlFactory.boolean(config, "show_fps", {
		name = "Show FPS",
		keywords = {"performance"},
		tip = "Display frame timings.",
	})

	t:eq(control.setting_name, "Show FPS")
	t:tdeq(control.setting_keywords, {"performance"})
	t:eq(control.tip, "Display frame timings.")
	t:eq(control.setting_key, "show_fps")
	control:activate()
	t:eq(config:getBoolean("show_fps"), true)
end

---@param t testing.T
function test.number_uses_definition_metadata_and_conversions(t)
	local config = Config(FakeFilesystem(), "settings.json")
	config:setDefaultNumber("volume", 0.5, 0, 1, 0.01)
	local control = ControlFactory.number(config, "volume", {
		name = "Volume",
		from_storage = function(value) return value * 100 end,
		to_storage = function(value) return value / 100 end,
		min = 0,
		max = 100,
		step = 1,
	})

	t:eq(control.value, 50)
	control:setValue(75, true)
	t:eq(config:getNumber("volume"), 0.75)
end

---@param t testing.T
function test.key_bindings_bind_ui_config(t)
	local config = Config(FakeFilesystem(), "ui.json")
	config:setDefaultKeyBindings("open_config", {{key = "o", control = true}})
	local control = ControlFactory.keyBindings(config, "open_config", {
		name = "Open settings",
	})

	t:eq(control:getText(), "Ctrl+o")
	control:setText("Shift+p", true)
	t:tdeq(config:getKeyBindings("open_config"), {{key = "p", shift = true}})
end

return test
