local FilePicker = require("rizu.mapperatorinator.FilePicker")

local test = {}

local function pipeWith(value, ok, code)
	return {
		read = function() return value end,
		close = function() return ok == nil and nil or ok, "exit", code end,
	}
end

---@param t testing.T
function test.builds_open_dialog(t)
	local command
	local picker = FilePicker(function(value)
		command = value
		return pipeWith("/maps/reference.osu", true, 0)
	end)
	local old_os = jit.os
	jit.os = "Linux"
	local path = picker:open("Select reference", {"osu! beatmaps | *.osu"})
	jit.os = old_os
	t:eq(path, "/maps/reference.osu")
	t:assert(command:find("zenity --file-selection", 1, true))
	t:assert(command:find("--file-filter='osu! beatmaps | *.osu'", 1, true))
end

---@param t testing.T
function test.builds_save_dialog(t)
	local command
	local picker = FilePicker(function(value)
		command = value
		return pipeWith("/tmp/preset.json", true, 0)
	end)
	local old_os = jit.os
	jit.os = "Linux"
	local path = picker:save("Export preset", "mapperatorinator-preset.json", {"JSON presets | *.json"})
	jit.os = old_os
	t:eq(path, "/tmp/preset.json")
	t:assert(command:find("--save --confirm-overwrite", 1, true))
	t:assert(command:find("--filename='mapperatorinator-preset.json'", 1, true))
end

return test
