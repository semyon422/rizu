local AudioFilePicker = require("rizu.mapperatorinator.AudioFilePicker")

local test = {}

---@param t testing.T
function test.returns_selected_path(t)
	local dialog_type, settings
	local picker = AudioFilePicker(function(value, callback, options)
		dialog_type = value
		settings = options
		callback({"/music/song.ogg"}, "Audio files", nil)
	end)
	local selected, selected_err
	picker:pick(function(path, err)
		selected, selected_err = path, err
	end)
	t:eq(selected, "/music/song.ogg")
	t:eq(selected_err, nil)
	t:eq(dialog_type, "openfile")
	t:eq(settings.title, "Select audio for Mapperatorinator")
	t:eq(settings.filters["Audio files"], "mp3;wav;ogg;m4a;flac")
	t:eq(settings.filters["All files"], "*")
	t:eq(settings.attachtowindow, true)
end

---@param t testing.T
function test.cancel_returns_nil(t)
	local picker = AudioFilePicker(function(_, callback)
		callback({}, nil, nil)
	end)
	local selected = false
	picker:pick(function(path) selected = path end)
	t:eq(selected, nil)
end

return test
