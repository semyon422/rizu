local FakeFilesystem = require("fs.FakeFilesystem")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local fs_util = require("fs.util")
local Shell = require("rizu.build.Shell")
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

---@param t testing.T
function test.preserves_permissions_in_client_and_macos_archives(t)
	local fs = LinuxFilesystem()
	local shell = Shell()
	fs:createDirectory("tmp")
	local dir = assert(shell:popen("mktemp -d 'tmp/package permissions.XXXXXX'")):match("^%s*(.-)%s*$")
	assert(dir)
	---@type string
	local root = fs:getWorkingDirectory()
	local source = dir .. "/source"
	---@type boolean, string?
	local ok, err = xpcall(function()
		for _, path in ipairs({
			"main.lua", "conf.lua", "rizu/game/GameInteractor.lua",
			"app_config.lua", "nginx_config.lua", "bancho_config.lua", "package_config.lua",
			"chart/model/notes/Notes.lua", "gui/Screen.lua", "rizu/ai/SystemPrompt.md",
			"resources/needle/needle-q8-stripped.bin",
			"bin/linux64/libneedle_runtime.so", "bin/win64/needle_runtime.dll",
			"bin/mac64/libneedle_runtime.dylib", "bin/linux64/tool with space",
			"game-appimage", "game-macos", "game-win64.bat",
			"mac-runtime/love.app/Contents/MacOS/love",
			"mac-runtime/love.app/Contents/Frameworks/runtime.dylib",
		}) do
			fs:createDirectory(source .. "/" .. assert(path:match("^(.*)/") or ""))
			assert(fs:write(source .. "/" .. path, "payload: " .. path))
		end
		for _, path in ipairs({"game-appimage", "game-macos", "bin/linux64/tool with space"}) do
			shell:execute(("chmod 751 %q"):format(source .. "/" .. path))
		end
		shell:execute(("chmod 640 %q"):format(source .. "/game-win64.bat"))
		shell:execute(("chmod 755 %q"):format(source .. "/mac-runtime/love.app/Contents/MacOS/love"))

		local runner = ([=[
local ffi = require("ffi")
local LinuxFilesystem = require("fs.LinuxFilesystem")
local Context = require("rizu.build.Context")
local Shell = require("rizu.build.Shell")
local RepoAssembler = require("rizu.build.package.RepoAssembler")
local ZipPackager = require("rizu.build.package.ZipPackager")
local MacOSPackager = require("rizu.build.package.MacOSPackager")
local root, source = %q, %q
for _, key in ipairs({"path", "cpath"}) do
	package[key] = package[key]:gsub("([^;]+)", function(path)
		return path:sub(1, 1) == "/" and path or root .. "/" .. path
	end)
end
ffi.cdef("int chdir(const char *path);")
assert(ffi.C.chdir(source) == 0)
local fs, shell = LinuxFilesystem(), Shell()
local ctx = Context(fs, shell, {})
RepoAssembler(ctx):build()
local love_listing = "\n" .. assert(shell:popen("unzip -Z1 build/repo/rizu/game.love"))
for _, name in ipairs({"app_config.lua", "nginx_config.lua", "bancho_config.lua", "package_config.lua"}) do
	assert(not love_listing:find("\n" .. name .. "\n", 1, true), "server config in client: " .. name)
end
ZipPackager(ctx):build()
shell:execute("mkdir -p build/downloads; cd mac-runtime && zip -qry ../build/downloads/love-macos.zip love.app")
local macos = MacOSPackager(ctx)
function macos:makeLibrariesPortable() end
macos:build()
shell:execute("unzip -oq build/repo/rizu.zip -d restored; unzip -oq build/repo/rizu_macos.zip -d restored-macos")
]=]):format(root, root .. "/" .. source)
		assert(fs:write(dir .. "/runner.lua", runner))
		shell:execute(("umask 077; ./luajit %q"):format(dir .. "/runner.lua"))

		---@param path string
		---@return string?
		local function mode(path)
			return assert(shell:popen(("stat -c '%%a' %q"):format(source .. "/" .. path))):match("%d+")
		end
		for _, prefix in ipairs({
			"build/repo/rizu/", "restored/rizu/",
			"restored-macos/rizu.app/Contents/Resources/",
		}) do
			for _, launcher in ipairs({"game-appimage", "game-macos"}) do
				t:eq(mode(prefix .. launcher), "751")
				t:eq(fs:read(source .. "/" .. prefix .. launcher), "payload: " .. launcher)
			end
			t:eq(mode(prefix .. "game-win64.bat"), "640")
		end
		for _, prefix in ipairs({"build/repo/rizu/", "restored/rizu/"}) do
			t:eq(mode(prefix .. "bin/linux64/tool with space"), "751")
		end
		t:eq(mode("restored-macos/rizu.app/Contents/MacOS/love"), "755")
	end, debug.traceback)
	fs_util.remove(dir, fs)
	assert(ok, err)
end

return test
