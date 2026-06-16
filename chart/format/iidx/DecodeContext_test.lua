local DecodeContext = require("chart.format.iidx.DecodeContext")
local FakeFilesystem = require("fs.FakeFilesystem")
local Fixtures = require("chart.format.iidx.TestFixtures")

local test = {}

---@param t testing.T
function test.from_location(t)
	local fs = FakeFilesystem()
	fs:createDirectory("data")
	fs:createDirectory("data/info")
	fs:createDirectory("data/info/0")
	fs:createDirectory("data/sound")
	fs:write("data/info/0/music_data.bin", Fixtures.sampleMusicDb())

	local context = assert(DecodeContext.fromLocation(fs, "data", "01234/01234.1"))

	t:eq(context.song_id, 1234)
	t:eq(context.iidx_song.title, "Fixture Song")
	t:eq(context.iidx_song.idents.SPN, 48)
end

---@param t testing.T
function test.missing_location(t)
	local fs = FakeFilesystem()

	t:eq(DecodeContext.fromLocation(fs, "data", "01234/01234.1"), nil)
end

return test
