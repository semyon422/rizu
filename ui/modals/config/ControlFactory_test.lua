local ControlFactory = require("ui.modals.config.ControlFactory")
local Config = require("rizu.config.Config")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

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
function test.boolean_binds_legacy_setting(t)
	local settings = {graphics = {unlimited_fps = false}}
	local changed
	local control = ControlFactory.legacyBoolean(settings, {"graphics", "unlimited_fps"}, {
		name = "Unlimited FPS",
		on_change = function(value)
			changed = value
		end,
	})

	t:eq(control.setting_key, "graphics.unlimited_fps")
	control:activate()
	t:eq(settings.graphics.unlimited_fps, true)
	t:eq(changed, true)
end

return test
