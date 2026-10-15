local SettingsFilter = require("ui.modals.config.SettingsFilter")

local test = {}

---@param name string?
---@param keywords string[]?
---@param tip string?
---@return ui.views.form.FormControl
local function control(name, keywords, tip)
	return {setting_name = name, setting_keywords = keywords or {}, tip = tip} ---@diagnostic disable-line
end

---@param t testing.T
function test.parse_splits_and_lowercases(t)
	t:tdeq(SettingsFilter.parse("  Audio   LATENCY "), {"audio", "latency"})
	t:tdeq(SettingsFilter.parse(""), {})
end

---@param t testing.T
function test.empty_query_keeps_everything(t)
	local controls = {control("A"), control(nil)}
	t:eq(SettingsFilter.filterControls({}, "Section", controls), controls)
end

---@param t testing.T
function test.matches_name_keywords_and_tip(t)
	local c = control("Universal offset", {"latency"}, "Shifts all notes")
	t:eq(SettingsFilter.matchesControl({"universal"}, c, "Offset"), true)
	t:eq(SettingsFilter.matchesControl({"latency"}, c, "Offset"), true)
	t:eq(SettingsFilter.matchesControl({"notes"}, c, "Offset"), true)
	t:eq(SettingsFilter.matchesControl({"volume"}, c, "Offset"), false)
end

---@param t testing.T
function test.all_terms_must_match(t)
	local c = control("Universal offset", {"latency"})
	t:eq(SettingsFilter.matchesControl({"universal", "latency"}, c, "Offset"), true)
	t:eq(SettingsFilter.matchesControl({"universal", "volume"}, c, "Offset"), false)
end

---@param t testing.T
function test.unnamed_control_needs_empty_query(t)
	t:eq(SettingsFilter.matchesControl({"a"}, control(nil), "Section"), false)
end

---@param t testing.T
function test.section_name_match_keeps_whole_section(t)
	local controls = {control("One"), control(nil)}
	t:eq(SettingsFilter.filterControls({"audio"}, "Audio Volume", controls), controls)
end

---@param t testing.T
function test.filter_drops_non_matching(t)
	local a, b = control("Master volume"), control("Music volume")
	local kept = SettingsFilter.filterControls({"master"}, "Audio", {a, b})
	t:eq(#kept, 1)
	t:eq(kept[1], a)
end

return test
