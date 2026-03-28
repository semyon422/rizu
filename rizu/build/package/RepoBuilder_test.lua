local RepoBuilder = require("rizu.build.package.RepoBuilder")
local FakeFilesystem = require("fs.FakeFilesystem")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local ZipFilesystem = require("fs.ZipFilesystem")
local Context = require("rizu.build.Context")
local config = require("rizu.build.package.config")

local _name = config.repo.name

---@class rizu.build.MockShell: rizu.build.IShell
---@operator call: rizu.build.MockShell
local MockShell = require("class")()
function MockShell:execute(cmd) return true, 0 end
function MockShell:popen(cmd)
	if cmd:find("git log.*%%cd") then return "Mon Jan 1 00:00:00 2024 +0000" end
	if cmd:find("git log.*%%H") then return "1234567890abcdef" end
	return ""
end

local CurrentRepo = require("rizu.build.package.CurrentRepo")

local test = {}

---@param t testing.T
function test.build_and_package(t)
	local fs = FakeFilesystem()
	local src_fs = LinuxFilesystem()
	local shell = MockShell()
	local ctx = Context(fs, shell, nil, "linux", ".")

	local git_repo = CurrentRepo(ctx)
	-- When using real FS, "." is the current project root which has all files
	function git_repo:getDirName() return "." end

	local builder = RepoBuilder(ctx, git_repo, src_fs)

	-- Test build()
	-- This will read from LinuxFilesystem and write to FakeFilesystem
	builder:build()

	-- Verify repo/ files exist in FakeFilesystem
	t:assert(fs:getInfo("build/repo/" .. _name))
	t:assert(fs:getInfo("build/repo/files.json"), "files.json should be generated")
	t:assert(fs:getInfo("build/repo/" .. _name .. "/game.love"), "game.love should be generated")

	-- Check if some core files from the real project were copied into game.love
	local zfs_game = ZipFilesystem(fs:read("build/repo/" .. _name .. "/game.love"))
	t:assert(zfs_game:getInfo("rizu/game/GameInteractor.lua"), "rizu/game/GameInteractor.lua should be inside game.love")
	t:assert(zfs_game:getInfo("conf.lua"), "conf.lua should be inside game.love")
	t:assert(zfs_game:getInfo("main.lua"), "main.lua should be inside game.love")

	-- Verify 3rd-deps/lib mapping
	if src_fs:getInfo("3rd-deps/lib/gd.so") then
		t:assert(fs:getInfo("build/repo/" .. _name .. "/bin/linux64/gd.so"), "gd.so should be in linux64")
	end
	if src_fs:getInfo("3rd-deps/lib/ssl.dll") then
		t:assert(fs:getInfo("build/repo/" .. _name .. "/bin/win64/ssl.dll"), "ssl.dll should be in win64")
	end
	if src_fs:getInfo("3rd-deps/lib/ssl.dylib") then
		t:assert(fs:getInfo("build/repo/" .. _name .. "/bin/mac64/ssl.dylib"), "ssl.dylib should be in mac64")
	end

	-- Test build_zip()
	builder:build_zip()
	t:assert(fs:getInfo("build/repo/" .. _name .. ".zip"), "rizu.zip should be generated")

	-- Test buildMacos()
	-- This requires build/downloads/love-macos.zip to exist in real FS
	builder:buildMacos()
	t:assert(fs:getInfo("build/repo/" .. _name .. "_macos.zip"), "macos zip should be generated")
	local mac_zfs = ZipFilesystem(fs:read("build/repo/" .. _name .. "_macos.zip"))
	t:assert(mac_zfs:getInfo(_name .. ".app/Contents/MacOS/love"), "love binary should be in macos zip")
end

return test
