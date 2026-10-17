local BackgroundFinder = require("rizu.preview.BackgroundFinder")
local PreviewMediaProbe = require("rizu.preview.PreviewMediaProbe")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@param t testing.T
function test.find_background_and_probe_cache(t)
	local fs = FakeFilesystem()
	fs:createDirectory("songs")
	fs:createDirectory("userdata/audio_previews")
	fs:write("songs/bg.jpg", "image")
	fs:write("songs/banner.jpg", "banner")
	t:eq(BackgroundFinder(fs):find("songs/"), "songs/bg.jpg")
	t:eq(BackgroundFinder(fs):find("songs/bg.jpg"), "songs/bg.jpg")
	fs:write("userdata/audio_previews/hash.audio_preview", "audio")
	local info = PreviewMediaProbe(fs):probe({hash = "hash", location_dir = "songs", format = "osu"})
	t:eq(info.audio_exists, true)
	t:eq(info.bga_exists, false)
	t:tdeq(info.bga_paths, {"songs"})
end

return test
