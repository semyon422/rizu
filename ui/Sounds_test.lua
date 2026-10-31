local FakeFilesystem = require("fs.FakeFilesystem")
local Settings = require("rizu.config.Settings")
local Sounds = require("ui.Sounds")

local test = {}

function test.load_mounts_sounds_archive(t)
	Sounds.load(Settings.createConfig(FakeFilesystem()))
	Sounds.load(Settings.createConfig(FakeFilesystem()))
	t:assert(love.filesystem.getInfo(Sounds.sounds_dir .. "/click.ogg", "file"))
	Sounds.settings = nil
end

return test
