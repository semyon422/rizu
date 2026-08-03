local class = require("class")
local config = require("rizu.build.package.config")
local fs_util = require("fs.util")

local ArchiveUtil = require("rizu.build.package.ArchiveUtil")
local RepoConfigWriter = require("rizu.build.package.RepoConfigWriter")

local _name = config.repo.name

local EXPECTED_FFMPEG_FILES = {
	linux64 = {
		"libavcodec.so.62",
		"libavdevice.so.62",
		"libavfilter.so.11",
		"libavformat.so.62",
		"libavutil.so.60",
		"libswresample.so.6",
		"libswscale.so.9",
	},
	win64 = {
		"avcodec-62.dll",
		"avdevice-62.dll",
		"avfilter-11.dll",
		"avformat-62.dll",
		"avutil-60.dll",
		"swresample-6.dll",
		"swscale-9.dll",
	},
}

local FFMPEG_FILE_PATTERNS = {
	linux64 = {"^libav[^/]+%.so%.%d+$", "^libsw[^/]+%.so%.%d+$"},
	win64 = {"^av[^/]+%-%d+%.dll$", "^sw[^/]+%-%d+%.dll$"},
}

---@class rizu.build.package.RepoAssembler
---@operator call: rizu.build.package.RepoAssembler
---@field ctx rizu.build.Context
---@field src_fs fs.IFilesystem
---@field config_writer rizu.build.package.RepoConfigWriter
local RepoAssembler = class()

---@param ctx rizu.build.Context
---@param src_fs? fs.IFilesystem
function RepoAssembler:new(ctx, src_fs)
	self.ctx = ctx
	self.src_fs = src_fs or ctx.fs
	self.config_writer = RepoConfigWriter(ctx)
end

---@param gamerepo string
---@param bin_root string
function RepoAssembler:removeStaleFfmpeg(bin_root)
	for platform, patterns in pairs(FFMPEG_FILE_PATTERNS) do
		local expected = {}
		for _, name in ipairs(EXPECTED_FFMPEG_FILES[platform]) do expected[name] = true end
		local platform_dir = bin_root .. "/" .. platform
		if self.ctx.fs:getInfo(platform_dir) then
			for _, name in ipairs(self.ctx.fs:getDirectoryItems(platform_dir)) do
				for _, pattern in ipairs(patterns) do
					if name:match(pattern) and not expected[name] then
						self.ctx.fs:remove(platform_dir .. "/" .. name)
						break
					end
				end
			end
		end
	end
end

---@param gamerepo string
function RepoAssembler:validate(gamerepo)
	assert(self.ctx.fs:getInfo(gamerepo) ~= nil, "missing repo directory: " .. gamerepo)
	local game_love = gamerepo .. "/game.love"
	assert(self.ctx.fs:getInfo(game_love) ~= nil, "missing game.love: " .. game_love)

	local game_zip_listing = ArchiveUtil.getZipListing(self.ctx, game_love)
	assert(ArchiveUtil.hasEntry(game_zip_listing, "rizu/game/GameInteractor.lua"), "game.love is missing rizu/game/GameInteractor.lua")
	assert(ArchiveUtil.hasEntry(game_zip_listing, "chart/model/notes/Notes.lua"), "game.love is missing chart/model/notes/Notes.lua")
	assert(ArchiveUtil.hasEntry(game_zip_listing, "gui/Screen.lua"), "game.love is missing gui/Screen.lua")
	assert(ArchiveUtil.hasEntry(game_zip_listing, "rizu/ai/SystemPrompt.md"), "game.love is missing rizu/ai/SystemPrompt.md")
	assert(ArchiveUtil.hasEntry(game_zip_listing, "conf.lua"), "game.love is missing conf.lua")
	assert(ArchiveUtil.hasEntry(game_zip_listing, "main.lua"), "game.love is missing main.lua")
	assert(self.ctx.fs:getInfo(gamerepo .. "/resources/needle/needle-q8-stripped.bin") ~= nil,
		"missing bundled Needle model")
	assert(self.ctx.fs:getInfo(gamerepo .. "/bin/linux64/libneedle_runtime.so") ~= nil,
		"missing Linux Needle runtime")
	assert(self.ctx.fs:getInfo(gamerepo .. "/bin/win64/needle_runtime.dll") ~= nil,
		"missing Windows Needle runtime")
	assert(self.ctx.fs:getInfo(gamerepo .. "/bin/mac64/libneedle_runtime.dylib") ~= nil,
		"missing macOS Needle runtime")

	local lib_src = "3rd-deps/lib/"
	if self.src_fs:getInfo(lib_src .. "gd.so") then
		assert(self.ctx.fs:getInfo(gamerepo .. "/bin/linux64/gd.so") ~= nil, "missing linux64 gd.so")
	end
	if self.src_fs:getInfo(lib_src .. "ssl.dll") then
		assert(self.ctx.fs:getInfo(gamerepo .. "/bin/win64/ssl.dll") ~= nil, "missing win64 ssl.dll")
	end
	if self.src_fs:getInfo(lib_src .. "ssl.dylib") then
		assert(self.ctx.fs:getInfo(gamerepo .. "/bin/mac64/ssl.dylib") ~= nil, "missing mac64 ssl.dylib")
	end
end

function RepoAssembler:build()
	self.ctx.fs:createDirectory("build/repo")

	local gamerepo = "build/repo/" .. _name
	local gamedir = gamerepo .. "/gamedir.love"

	fs_util.remove(gamerepo, self.ctx.fs)
	self.ctx.fs:createDirectory(gamerepo)
	self.ctx.fs:createDirectory(gamedir)

	print("Copying core folders...")
	for _, dir in ipairs(config.repo.include) do
		if self.src_fs:getInfo(dir) then
			fs_util.copy(dir, gamedir .. "/" .. dir, self.src_fs, self.ctx.fs)
		end
	end

	print("Copying root lua files...")
	local root_items = self.src_fs:getDirectoryItems(".")
	for _, item in ipairs(root_items) do
		if item:match("%.lua$") then
			local info = self.src_fs:getInfo(item)
			if info and info.type == "file" then
				fs_util.copy(item, gamedir .. "/" .. item, self.src_fs, self.ctx.fs)
			end
		end
	end

	print("Copying 3rd-deps/lua...")
	self.ctx.fs:createDirectory(gamedir .. "/3rd-deps")
	if self.src_fs:getInfo("3rd-deps/lua") then
		fs_util.copy("3rd-deps/lua", gamedir .. "/3rd-deps/lua", self.src_fs, self.ctx.fs)
	end

	print("Extracting platform files...")
	for _, dir in ipairs(config.repo.extract) do
		if self.src_fs:getInfo(dir) then
			fs_util.copy(dir, gamerepo .. "/" .. dir, self.src_fs, self.ctx.fs)
		end
	end
	self:removeStaleFfmpeg(gamerepo .. "/bin")

	if self.src_fs:getInfo("3rd-deps/lib") then
		local libs = self.src_fs:getDirectoryItems("3rd-deps/lib")
		for _, lib in ipairs(libs) do
			local ext = lib:match("%.([^.]+)$")
			local subdir
			if ext == "so" then
				subdir = "linux64"
			elseif ext == "dll" then
				subdir = "win64"
			elseif ext == "dylib" then
				subdir = "mac64"
			end

			if subdir then
				local dst_dir = gamerepo .. "/bin/" .. subdir
				self.ctx.fs:createDirectory(dst_dir)
				fs_util.copy("3rd-deps/lib/" .. lib, dst_dir .. "/" .. lib, self.src_fs, self.ctx.fs)
			end
		end
	end

	print("Cleaning up unnecessary files...")
	local runtime_assets = {}
	for _, path in ipairs(config.repo.runtime_assets) do
		runtime_assets[gamedir .. "/" .. path] = true
	end
	local to_delete = {}
	fs_util.find(gamedir, self.ctx.fs, function(path)
		if not path:match("%.lua$") and not path:match("%.c$") and not path:match("%.sql$") and not runtime_assets[path] then
			table.insert(to_delete, path)
		end
	end)
	for _, path in ipairs(to_delete) do self.ctx.fs:remove(path) end

	to_delete = {}
	fs_util.find(gamerepo, self.ctx.fs, function(path)
		local name = path:match("([^/]+)$")
		if name and name:sub(1, 1) == "." then
			table.insert(to_delete, path)
		end
	end)
	for _, path in ipairs(to_delete) do self.ctx.fs:remove(path) end

	fs_util.removeEmptyDirs(gamerepo, self.ctx.fs)

	self.config_writer:write(gamedir)

	print("Zipping game.love...")
	self.ctx.shell:execute(string.format("bash -lc 'cd %q && zip -qry %q .'", gamedir, "../game.love"))
	fs_util.remove(gamedir, self.ctx.fs)

	if self.src_fs:getInfo("conf.lua") then
		fs_util.copy("conf.lua", gamerepo .. "/conf.lua", self.src_fs, self.ctx.fs)
	end
	if self.src_fs:getInfo("rizu/build/package/conf.lua") then
		fs_util.copy("rizu/build/package/conf.lua", gamerepo .. "/conf.lua", self.src_fs, self.ctx.fs)
	end

	self:validate(gamerepo)
end

return RepoAssembler
