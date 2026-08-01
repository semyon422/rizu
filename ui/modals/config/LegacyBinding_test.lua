local LegacyBinding = require("ui.modals.config.LegacyBinding")

local test = {}

---@param t testing.T
function test.resolves_nested_legacy_setting(t)
	local settings = {audio = {volume = {master = 0.5}}}
	local parent, key = LegacyBinding.resolve(settings, {"audio", "volume", "master"})

	t:eq(parent, settings.audio.volume)
	t:eq(key, "master")
	t:eq(LegacyBinding.key({"audio", "volume", "master"}), "audio.volume.master")
end

---@param t testing.T
function test.rejects_unknown_path(t)
	t:has_error(function()
		LegacyBinding.resolve({}, {"audio", "volume"})
	end)
end

return test
