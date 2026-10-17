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
end

---@param t testing.T
function test.validates_override_values(t)
	local config = SkinConfig()
	t:has_error(function() config:set("mania", "4key", "invalid", {}) end) ---@diagnostic disable-line
	t:has_error(function() config:set("mania", "4key", "invalid", 0 / 0) end)
end

---@param t testing.T
function test.replaces_overrides(t)
	local config = SkinConfig({mania = {["4key"] = {["receptor.y"] = 360}}})
	config:replaceOverrides({mania = {["7key1scratch"] = {["receptor.y"] = 340}}})
	t:eq(config:get("mania", "4key", "receptor.y"), nil)
	t:eq(config:get("mania", "7key1scratch", "receptor.y"), 340)
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
	t:eq(loaded:get("mania", "4key", "receptor.y"), 342)
	t:eq(loaded:get("mania", "7key1scratch", "field.offset_x"), -16)
	t:eq(loaded:get("mania", "5key", "receptor.y"), nil)
end

return test
