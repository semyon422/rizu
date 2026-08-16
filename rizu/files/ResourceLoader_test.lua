local ResourceLoader = require("rizu.files.ResourceLoader")
local ResourceFinder = require("rizu.files.ResourceFinder")
local FakeFilesystem = require("fs.FakeFilesystem")
local Resources = require("chart.core.Resources")
local Fixtures = require("chart.format.iidx.TestFixtures")

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

---@param t testing.T
function test.resource_entries(t)
	local res = Resources()
	res:add("sound", "audio.ogg", "audio.mp3")
	res:add("image", "bg.png")

	local entries = ResourceLoader.getResourceEntries(res)
	table.sort(entries, function(a, b)
		return a.type < b.type
	end)

	t:tdeq(entries, {
		{
			type = "image",
			paths = {"bg.png"},
		},
		{
			type = "sound",
			paths = {"audio.ogg", "audio.mp3"},
		},
	})
end

---@param t testing.T
function test.apply_snapshot(t)
	local fs = FakeFilesystem()
	local rf = ResourceFinder(fs)
	local rl = ResourceLoader(fs, rf)
	local res = Resources()

	fs:createDirectory("dir")
	fs:write("dir/audio.mp3", "audio")

	rf:addPath("dir")
	res:add("sound", "audio.mp3")
	rl:load(res)

	local rf2 = ResourceFinder(fs)
	local rl2 = ResourceLoader(fs, rf2)
	rl2:applySnapshot(rl:getSnapshot())

	t:eq(rl2:getResource("audio.mp3"), "audio")
	t:eq(rf2:findFile("AUDIO.ogg"), "dir/audio.mp3")
end

---@param t testing.T
function test.video_keeps_path_without_loading_content(t)
	local fs = FakeFilesystem()
	local rf = ResourceFinder(fs)
	local rl = ResourceLoader(fs, rf)
	local res = Resources()

	fs:createDirectory("dir")
	fs:write("dir/movie.mp4", "video")
	rf:addPath("dir")
	res:add("video", "movie.mp4")

	rl:load(res)

	t:eq(rl.file_paths["movie.mp4"], "dir/movie.mp4")
	t:eq(rl.file_contents["dir/movie.mp4"], nil)
	t:eq(rl:getResource("movie.mp4"), nil)
end

---@param t testing.T
function test.iidx_s3p_inside_ifs(t)
	local fs = FakeFilesystem()
	local rf = ResourceFinder(fs)
	local rl = ResourceLoader(fs, rf)
	local res = Resources()

	local s3p = Fixtures.s3p({"sound0", "sound1"})
	fs:createDirectory("data")
	fs:createDirectory("data/sound")
	fs:write("data/sound/01234.ifs", Fixtures.ifs(1234, Fixtures.sampleChart(), s3p))

	rf:addPath("data/sound/01234.ifs")
	res:add("s3p", "01234/01234.s3p")

	rl:load(res)

	t:eq(rl:getResource("0"), nil)
	t:eq(rl:getResource("1"), "sound0")
	t:eq(rl:getResource("2"), "sound1")
end

---@param t testing.T
function test.iidx_2dx_inside_ifs(t)
	local fs = FakeFilesystem()
	local rf = ResourceFinder(fs)
	local rl = ResourceLoader(fs, rf)
	local res = Resources()

	local two_dx = Fixtures.twoDx("012341", {"sound1", "sound2"})
	fs:createDirectory("data")
	fs:createDirectory("data/sound")
	fs:write("data/sound/01234.ifs", Fixtures.ifs(1234, Fixtures.sampleChart(), nil, {
		{path = "01234/012341.2dx", data = two_dx, time = 1234},
	}))

	rf:addPath("data/sound/01234.ifs")
	res:add("2dx", "01234/012341.2dx")

	rl:load(res)

	t:eq(rl:getResource("0"), nil)
	t:eq(rl:getResource("1"), "sound1")
	t:eq(rl:getResource("2"), "sound2")
	t:eq(rl.file_contents["data/sound/01234.ifs/01234/012341.2dx"], nil)
end

---@param t testing.T
function test.iidx_2dx_fallbacks_inside_ifs(t)
	local fs = FakeFilesystem()
	local rf = ResourceFinder(fs)
	local rl = ResourceLoader(fs, rf)
	local res = Resources()

	local first_two_dx = Fixtures.twoDx("012340", {"sound1"})
	local second_two_dx = Fixtures.twoDx("012341", {"fallback1", "sound2"})
	fs:createDirectory("data")
	fs:createDirectory("data/sound")
	fs:write("data/sound/01234.ifs", Fixtures.ifs(1234, Fixtures.sampleChart(), nil, {
		{path = "01234/01234.2dx", data = first_two_dx, time = 1234},
		{path = "01234/012341.2dx", data = second_two_dx, time = 1235},
	}))

	rf:addPath("data/sound/01234.ifs")
	res:add("2dx", "01234/01234.2dx", "01234/012341.2dx")

	rl:load(res)

	t:eq(rl:getResource("1"), "sound1")
	t:eq(rl:getResource("2"), "sound2")
end

return test
