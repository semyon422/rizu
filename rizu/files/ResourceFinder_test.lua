local ResourceFinder = require("rizu.files.ResourceFinder")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@param t testing.T
function test.find_file(t)
	local fs = FakeFilesystem()
	local rf = ResourceFinder(fs)

	fs:createDirectory("dir")
	fs:write("dir/audio.mp3", "")

	rf:addPath("dir")

	t:eq(rf:findFile("audio.mp3"), "dir/audio.mp3")
	t:eq(rf:findFile("/audio.mp3"), "dir/audio.mp3")
	t:eq(rf:findFile("\\audio.mp3"), "dir/audio.mp3")
end

---@param t testing.T
function test.equal_name_found(t)
	local fs = FakeFilesystem()
	local rf = ResourceFinder(fs)

	fs:createDirectory("dir")
	fs:write("dir/Audio.MP3", "")
	fs:write("dir/audio.mp3", "")

	rf:addPath("dir")

	t:eq(rf:findFile("audio.mp3"), "dir/audio.mp3")
end

---@param t testing.T
function test.case_insensetive(t)
	local fs = FakeFilesystem()
	local rf = ResourceFinder(fs)

	fs:createDirectory("dir")
	fs:write("dir/audio.mp3", "")

	rf:addPath("dir")

	t:eq(rf:findFile("AUDIO.MP3"), "dir/audio.mp3")
end

---@param t testing.T
function test.alternate_ext_ordered(t)
	local fs = FakeFilesystem()
	local rf = ResourceFinder(fs)

	fs:createDirectory("dir")
	fs:write("dir/audio.wav", "")
	fs:write("dir/audio.mp3", "")

	rf:addPath("dir")

	t:eq(rf:findFile("audio.ogg"), "dir/audio.wav")
end

---@param t testing.T
function test.nested_directories(t)
	local fs = FakeFilesystem()
	local rf = ResourceFinder(fs)

	fs:createDirectory("dir")
	fs:createDirectory("dir/subdir")
	fs:write("dir/subdir/audio.mp3", "")

	rf:addPath("dir")

	t:eq(rf:findFile("subdir/audio.mp3"), "dir/subdir/audio.mp3")
	t:eq(rf:findFile("SUBDIR/AUDIO.MP3"), "dir/subdir/audio.mp3")
	t:eq(rf:findFile("subdir/audio.ogg"), "dir/subdir/audio.mp3")
end

---@param t testing.T
function test.explicit_format(t)
	local fs = FakeFilesystem()
	local rf = ResourceFinder(fs)

	fs:createDirectory("dir")
	fs:write("dir/image.png", "")
	fs:write("dir/audio.mp3", "")

	rf:addPath("dir")

	t:eq(rf:findFile("image", "image"), "dir/image.png")
	t:eq(rf:findFile("audio", "audio"), "dir/audio.mp3")
	t:eq(rf:findFile("image", "audio"), nil)
end

---@param t testing.T
function test.exact_path_with_wrong_extension_does_not_match_explicit_format(t)
	local fs = FakeFilesystem()
	local rf = ResourceFinder(fs)

	fs:createDirectory("dir")
	fs:createDirectory("dir/sound")
	fs:write("dir/sound/29093.ifs", "")

	rf:addPath("dir")

	t:eq(rf:findFile("sound/29093.ifs", "image"), nil)
	t:eq(rf:findFile("sound/29093.ifs", "video"), nil)
end

---@param t testing.T
function test.extension_infers_format_before_explicit_type(t)
	local fs = FakeFilesystem()
	local rf = ResourceFinder(fs)

	fs:createDirectory("dir")
	fs:write("dir/01234.mp4", "")

	rf:addPath("dir")

	t:eq(rf:findFile("01234.mp4", "image"), "dir/01234.mp4")
end

---@param t testing.T
function test.exact_match_priority_across_paths(t)
	local fs = FakeFilesystem()
	local rf = ResourceFinder(fs)

	fs:createDirectory("dir1")
	fs:createDirectory("dir2")

	-- dir1 has a variant match (mp3 for ogg request)
	fs:write("dir1/audio.mp3", "")
	-- dir2 has an exact match
	fs:write("dir2/audio.ogg", "")

	rf:addPath("dir1")
	rf:addPath("dir2")

	-- The finder prioritizes the first path in the search list.
	-- Since dir1 is added first, its variant match (mp3) is found before dir2's exact match.
	t:eq(rf:findFile("audio.ogg"), "dir1/audio.mp3")
end

return test
