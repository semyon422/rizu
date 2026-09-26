local FakeFilesystem = require("fs.FakeFilesystem")
local SkinConfig = require("rizu.skin.SkinConfig")
local SkinConfigSerializer = require("rizu.skin.SkinConfigSerializer")

local test = {}

---@param t testing.T
function test.get_set_and_clear_overrides(t)
	local config = SkinConfig()
	t:eq(config:get("mania", "4key", "receptor.y", 360), 360)
	config:set("mania", "4key", "receptor.y", 342)
	t:eq(config.has_unsaved_changes, true)
	t:eq(config:get("mania", "4key", "receptor.y", 360), 342)
	config:set("mania", "4key", "receptor.y", nil)
	t:eq(config:get("mania", "4key", "receptor.y", 360), 360)
	t:tdeq(config:getOverrides(), {})
end

---@param t testing.T
function test.validates_override_values(t)
	local config = SkinConfig()
	t:has_error(function() config:set("mania", "4key", "invalid", {}) end) ---@diagnostic disable-line
	t:has_error(function() config:set("mania", "4key", "invalid", 0 / 0) end)
end

---@param t testing.T
function test.notifies_specific_and_global_subscribers(t)
	local config = SkinConfig()
	local changes = {}
	local unsubscribe = config:subscribe("mania", "4key", "receptor.y", function(value, old_value, gamemode, input_mode, key)
		changes[#changes + 1] = {value, old_value, gamemode, input_mode, key} ---@diagnostic disable-line
	end)
	config:subscribeAll(function(value, old_value, gamemode, input_mode, key)
		changes[#changes + 1] = {value, old_value, gamemode, input_mode, key} ---@diagnostic disable-line
	end)

	config:set("mania", "4key", "receptor.y", 340)
	config:set("mania", "4key", "receptor.y", 340)
	unsubscribe()
	config:set("mania", "4key", "receptor.y", 350)
	t:tdeq(changes, {
		{340, nil, "mania", "4key", "receptor.y"},
		{340, nil, "mania", "4key", "receptor.y"},
		{350, 340, "mania", "4key", "receptor.y"},
	})
end

---@param t testing.T
function test.replaces_overrides_and_notifies_subscribers(t)
	local config = SkinConfig({mania = {["4key"] = {["receptor.y"] = 360}}})
	local changes = {}
	config:subscribeAll(function(value, old_value, gamemode, input_mode, key)
		changes[#changes + 1] = {value, old_value, gamemode, input_mode, key} ---@diagnostic disable-line
	end)
	config:replaceOverrides({mania = {["7key1scratch"] = {["receptor.y"] = 340}}})
	t:eq(config:getOverride("mania", "4key", "receptor.y"), nil)
	t:eq(config:getOverride("mania", "7key1scratch", "receptor.y"), 340)
	t:tdeq(changes, {
		{nil, 360, "mania", "4key", "receptor.y"},
		{340, nil, "mania", "7key1scratch", "receptor.y"},
	})
end

---@param t testing.T
function test.serializer_round_trip_preserves_modes_and_unknown_properties(t)
	local overrides = {
		mania = {
			["4key"] = {["receptor.y"] = 342, ["future.renderer.setting"] = true},
			["7key1scratch"] = {["field.offset_x"] = -12.5},
		},
		taiko = {["1key"] = {["field.x"] = "center"}},
	}
	local serialized = SkinConfigSerializer.serialize(overrides)
	local decoded, decode_error = SkinConfigSerializer.deserialize(serialized)
	t:eq(decode_error, nil)
	t:tdeq(decoded, overrides)
end

---@param t testing.T
function test.serializer_rejects_invalid_data(t)
	local decoded, decode_error = SkinConfigSerializer.deserialize("not json")
	t:eq(decoded, nil)
	t:assert(decode_error)
	decoded = SkinConfigSerializer.deserialize([[{"version":2,"overrides":{}}]])
	t:eq(decoded, nil)
	decoded = SkinConfigSerializer.deserialize([[{"version":1,"overrides":{"mania":{"4key":{"x":null}}}}]])
	t:eq(decoded, nil)
end

---@param t testing.T
function test.persistence(t)
	local fs = FakeFilesystem()
	local config = SkinConfig()
	config:set("mania", "4key", "receptor.y", 342)
	config:set("mania", "7key1scratch", "field.offset_x", -16)
	t:eq(config:save(fs, "userdata/dlc/skins_rizu/base/skin-config.json"), true)
	t:eq(config.has_unsaved_changes, false)

	local loaded = SkinConfig()
	t:eq(loaded:load(fs, "userdata/dlc/skins_rizu/base/skin-config.json"), true)
	t:eq(loaded:getOverride("mania", "4key", "receptor.y"), 342)
	t:eq(loaded:getOverride("mania", "7key1scratch", "field.offset_x"), -16)
	t:eq(loaded:getOverride("mania", "5key", "receptor.y"), nil)
end

return test
