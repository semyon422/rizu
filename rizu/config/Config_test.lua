local Config = require("rizu.config.Config")
local FakeFilesystem = require("fs.FakeFilesystem")
local Settings = require("rizu.config.Settings")

local test = {}

---@return rizu.config.Config, fs.FakeFilesystem
local function createConfig()
	local fs = FakeFilesystem()
	local config = Config(fs, "settings.json")
	config:setDefaultNumber("volume", 0.5, 0, 1, 0.01)
	config:setDefaultChoice("interface", "new", {"old", "new"})
	config:setDefaultBoolean("show_fps", false)
	config:setDefaultString("name", "")
	config:setDefaultKeyBindings("cancel", {{key = "escape"}})
	return config, fs
end

---@param t testing.T
function test.settings_defaults(t)
	local config = Settings.createConfig(FakeFilesystem())
	t:eq(config:getString(Settings.keys.user_interface), "new")
	local volume = config:getDefinition(Settings.keys.audio.volume_master)
	t:eq(volume.min, 0)
	t:eq(volume.max, 1)
	t:eq(volume.step, 0.01)
end

---@param t testing.T
function test.number_defaults_and_bounds(t)
	local config = Config(FakeFilesystem(), "settings.json")
	config:setDefaultNumber("bounded", 5, 0, 10, 0.5)
	local definition = config:getDefinition("bounded")
	t:eq(definition.min, 0)
	t:eq(definition.max, 10)
	t:eq(definition.step, 0.5)
	t:has_error(function() config:setNumber("bounded", 11) end)
	t:has_error(function() config:setDefault("invalid", {kind = "number", default = 0}) end)
end

---@param t testing.T
function test.typed_access(t)
	local config = createConfig()
	t:eq(config:getNumber("volume"), 0.5)
	t:eq(config:getChoice("interface"), "new")
	t:eq(config:getBoolean("show_fps"), false)
	t:eq(config:getString("name"), "")
	t:tdeq(config:getKeyBindings("cancel"), {{key = "escape"}})
	t:tdeq(config:getChoices("interface"), {"old", "new"})

	config:setNumber("volume", 0.8)
	config:setChoice("interface", "old")
	config:setBoolean("show_fps", true)
	config:setString("name", "player")
	config:setKeyBindings("cancel", {{key = "q", control = true}})
	t:eq(config:getNumber("volume"), 0.8)
	t:eq(config:getChoice("interface"), "old")
	t:eq(config:getBoolean("show_fps"), true)
	t:eq(config:getString("name"), "player")
	t:tdeq(config:getKeyBindings("cancel"), {{key = "q", control = true}})
	local bindings = config:getKeyBindings("cancel")
	bindings[1].key = "mutated"
	t:eq(config:getKeyBindings("cancel")[1].key, "q")
end

---@param t testing.T
function test.rejects_invalid_access(t)
	local config = createConfig()
	t:has_error(function() config:getNumber("missing") end)
	t:has_error(function() config:getBoolean("volume") end)
	t:has_error(function() config:setNumber("volume", "loud") end) ---@diagnostic disable-line
	t:has_error(function() config:setChoice("interface", "missing") end)
	t:has_error(function() config:setDefaultBoolean("show_fps", true) end)
end

---@param t testing.T
function test.subscriptions(t)
	local config = createConfig()
	local changes = {}
	local unsubscribe = config:subscribe("show_fps", function(value, old_value, key)
		changes[#changes + 1] = {value, old_value, key} ---@diagnostic disable-line
	end)

	config:setBoolean("show_fps", true)
	config:setBoolean("show_fps", true)
	unsubscribe()
	config:setBoolean("show_fps", false)
	t:tdeq(changes, {{true, false, "show_fps"}})
end

---@param t testing.T
function test.typed_subscriptions(t)
	local config = createConfig()
	local number_value ---@type number?
	local choice_value ---@type string?
	local boolean_value ---@type boolean?
	local string_value ---@type string?
	local binding_key ---@type string?
	config:subscribeNumber("volume", function(value) number_value = value end)
	config:subscribeChoice("interface", function(value) choice_value = value end)
	config:subscribeBoolean("show_fps", function(value) boolean_value = value end)
	config:subscribeString("name", function(value) string_value = value end)
	config:subscribeKeyBindings("cancel", function(value) binding_key = value[1].key end)

	config:setNumber("volume", 0.7)
	config:setChoice("interface", "old")
	config:setBoolean("show_fps", true)
	config:setString("name", "player")
	config:setKeyBindings("cancel", {{key = "q"}})
	t:eq(number_value, 0.7)
	t:eq(choice_value, "old")
	t:eq(boolean_value, true)
	t:eq(string_value, "player")
	t:eq(binding_key, "q")
	t:has_error(function() config:subscribeBoolean("volume", function() end) end)
end

---@param t testing.T
function test.subscribe_all(t)
	local config = createConfig()
	local changed_key ---@type string?
	config:subscribeAll(function(_, _, key) changed_key = key end)
	config:setNumber("volume", 0.7)
	t:eq(changed_key, "volume")
end

---@param t testing.T
function test.persistence(t)
	local config, fs = createConfig()
	config:setNumber("volume", 0.8)
	config:setBoolean("show_fps", true)
	config:setKeyBindings("cancel", {{key = "q", control = true}})
	t:eq(config:save(), true)

	local loaded = Config(fs, "settings.json")
	loaded:setDefaultNumber("volume", 0.5, 0, 1, 0.01)
	loaded:setDefaultChoice("interface", "new", {"old", "new"})
	loaded:setDefaultBoolean("show_fps", false)
	loaded:setDefaultString("name", "")
	loaded:setDefaultKeyBindings("cancel", {{key = "escape"}})
	t:eq(loaded:load(), true)
	t:eq(loaded:getNumber("volume"), 0.8)
	t:eq(loaded:getBoolean("show_fps"), true)
	t:eq(loaded:getChoice("interface"), "new")
	t:tdeq(loaded:getKeyBindings("cancel"), {{key = "q", control = true}})
end

---@param t testing.T
function test.deserialize_ignores_unknown_keys(t)
	local config = createConfig()
	t:eq(config:deserialize([[{"unknown": 1, "show_fps": true}]]), true)
	t:eq(config:getBoolean("show_fps"), true)
end

return test
