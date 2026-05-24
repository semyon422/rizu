local ResourceLoader = require("rizu.files.ResourceLoader")
local ResourceFinder = require("rizu.files.ResourceFinder")
local FakeFilesystem = require("fs.FakeFilesystem")
local Resources = require("chart.core.Resources")

local test = {}

---@param t testing.T
function test.all(t)
	local fs = FakeFilesystem()
	local rf = ResourceFinder(fs)
	local rl = ResourceLoader(fs, rf)

	local res = Resources()
	res:add("sound", "audio.mp3")

	fs:createDirectory("dir1")
	fs:write("dir1/audio.mp3", "audio1")

	fs:createDirectory("dir2")
	fs:write("dir2/audio.mp3", "audio2")

	rf:addPath("dir1")

	rl:load(res)

	t:eq(rl:getResource("audio.mp3"), "audio1")
	t:eq(rl:getResource("audio.mp3"), "audio1")

	rf:reset()
	rf:addPath("dir2")

	rl:load(res)

	t:eq(rl:getResource("audio.mp3"), "audio2")
end

return test
