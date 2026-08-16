local FakeFilesystem = require("fs.FakeFilesystem")
local Settings = require("rizu.config.Settings")
local WindowModel = require("rizu.app.WindowModel")

local test = {}

---@param t testing.T
function test.set_resolution_updates_settings_and_window(t)
	local settings = Settings.createConfig(FakeFilesystem())
	local window_model = WindowModel(settings)
	local old_love = love
	local actual_width, actual_height, actual_flags
	_G.love = {
		window = {
			updateMode = function(width, height, flags)
				actual_width = width
				actual_height = height
				actual_flags = flags
			end,
		},
	}

	window_model:setResolution(1920, 1080)
	_G.love = old_love

	local keys = Settings.keys.graphics
	t:eq(settings:getNumber(keys.window_width), 1920)
	t:eq(settings:getNumber(keys.window_height), 1080)
	t:eq(actual_width, 1920)
	t:eq(actual_height, 1080)
	t:eq(actual_flags.fullscreen, false)
	t:eq(actual_flags.fullscreentype, "exclusive")
end

return test
