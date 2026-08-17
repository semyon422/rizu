local FilePicker = require("rizu.mapperatorinator.FilePicker")

local test = {}

---@param t testing.T
function test.builds_open_dialog(t)
	local dialog_type, settings
	local picker = FilePicker(function(value, callback, options)
		dialog_type = value
		settings = options
		callback({"/maps/reference.osu"}, "osu! beatmaps", nil)
	end)
	local selected
	picker:open("Select reference", {['osu! beatmaps'] = "osu"}, function(path) selected = path end)
	t:eq(selected, "/maps/reference.osu")
	t:eq(dialog_type, "openfile")
	t:eq(settings.title, "Select reference")
	t:eq(settings.filters["osu! beatmaps"], "osu")
	t:eq(settings.filters["All files"], "*")
	t:eq(settings.multiselect, false)
	t:eq(settings.attachtowindow, true)
end

---@param t testing.T
function test.builds_save_dialog(t)
	local dialog_type, settings
	local picker = FilePicker(function(value, callback, options)
		dialog_type = value
		settings = options
		callback({"/tmp/preset.json"}, "JSON presets", nil)
	end)
	local selected
	picker:save("Export preset", "mapperatorinator-preset.json", {['JSON presets'] = "json"}, function(path)
		selected = path
	end)
	t:eq(selected, "/tmp/preset.json")
	t:eq(dialog_type, "savefile")
	t:eq(settings.defaultname, "mapperatorinator-preset.json")
	t:eq(settings.filters["JSON presets"], "json")
end

---@param t testing.T
function test.forwards_dialog_errors(t)
	local picker = FilePicker(function(_, callback)
		callback({}, nil, "dialog failed")
	end)
	local selected, selected_err
	picker:open("Open", nil, function(path, err)
		selected, selected_err = path, err
	end)
	t:eq(selected, nil)
	t:eq(selected_err, "dialog failed")
end

return test
