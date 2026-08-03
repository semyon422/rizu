local FakeFilesystem = require("fs.FakeFilesystem")
local RepoAssembler = require("rizu.build.package.RepoAssembler")

local test = {}

---@param t testing.T
function test.removes_stale_ffmpeg_abis(t)
	local fs = FakeFilesystem()
	for _, platform in ipairs({"linux64", "win64"}) do
		fs:createDirectory("repo/bin/" .. platform)
	end
	for _, path in ipairs({
		"repo/bin/linux64/libavcodec.so.62",
		"repo/bin/linux64/libavcodec.so.63",
		"repo/bin/linux64/libswscale.so.9",
		"repo/bin/linux64/libswscale.so.10",
		"repo/bin/linux64/unrelated.so.1",
		"repo/bin/win64/avcodec-62.dll",
		"repo/bin/win64/avcodec-63.dll",
		"repo/bin/win64/swscale-9.dll",
		"repo/bin/win64/swscale-10.dll",
	}) do
		fs:write(path, path)
	end

	RepoAssembler({fs = fs}, fs):removeStaleFfmpeg("repo/bin")

	for _, path in ipairs({
		"repo/bin/linux64/libavcodec.so.62",
		"repo/bin/linux64/libswscale.so.9",
		"repo/bin/linux64/unrelated.so.1",
		"repo/bin/win64/avcodec-62.dll",
		"repo/bin/win64/swscale-9.dll",
	}) do
		t:assert(fs:getInfo(path), "expected retained file: " .. path)
	end
	for _, path in ipairs({
		"repo/bin/linux64/libavcodec.so.63",
		"repo/bin/linux64/libswscale.so.10",
		"repo/bin/win64/avcodec-63.dll",
		"repo/bin/win64/swscale-10.dll",
	}) do
		t:eq(fs:getInfo(path), nil)
	end
end

return test
