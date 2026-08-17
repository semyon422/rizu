local AudioFilePicker = require("rizu.mapperatorinator.AudioFilePicker")

local test = {}

---@param t testing.T
function test.returns_selected_path(t)
	local command
	local picker = AudioFilePicker(function(value)
		command = value
		return {
			read = function() return "/music/song.ogg" end,
			close = function() end,
		}
	end)
	local path, err = picker:pick()
	if jit.os == "Linux" then
		t:eq(path, "/music/song.ogg")
		t:eq(err, nil)
		t:assert(command:find("zenity --file-selection", 1, true))
		t:assert(command:find("*.mp3 *.wav *.ogg *.m4a *.flac", 1, true))
	else
		t:eq(path, nil)
		t:assert(err:find("Linux", 1, true))
	end
end

---@param t testing.T
function test.cancel_returns_nil(t)
	local picker = AudioFilePicker(function()
		return {
			read = function() return nil end,
			close = function() end,
		}
	end)
	local path = picker:pick()
	t:eq(path, nil)
end

return test
