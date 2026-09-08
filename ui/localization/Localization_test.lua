local Localization = require("ui.localization.Localization")

local test = {}

---@param t testing.T
function test.english_translation_and_key_fallback(t)
	local localization = Localization("en")
	t:eq(localization:get("main_menu.play"), "Play")
	t:has_error(function()
		localization:get("missing.key")
	end)
end

---@param t testing.T
function test.russian_translation_falls_back_to_english(t)
	local localization = Localization("ru")
	t:eq(localization:get("main_menu.play"), "Играть")
	t:eq(localization:get("main_menu.settings"), "Настройки")
	t:eq(localization:get("main_menu.play", {}), "Играть")
	t:eq(localization:get("settings.gameplay"), "Геймплей")
	t:eq(localization:get("settings.binding_retry"), "Рестарт карты")

	local unsupported = Localization("missing")
	t:eq(unsupported:get("main_menu.play"), "Play")
end

---@param t testing.T
function test.named_interpolation(t)
	local localization = Localization("en")
	t:eq(localization:get("remote_catalog.connecting", {url = "example.test"}), "Connecting to example.test")
	t:has_error(function()
		localization:get("remote_catalog.connecting")
	end)
	t:has_error(function()
		localization:get("remote_catalog.connecting", {url = {}})
	end)
end

---@param t testing.T
function test.validates_arguments(t)
	local localization = Localization("en")
	t:has_error(function() localization:get("") end) ---@diagnostic disable-line
	t:has_error(function() localization:get("main_menu.play", "invalid") end) ---@diagnostic disable-line
end

return test
