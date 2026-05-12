local class = require("class")
local config = require("rizu.build.package.config")
local fs_util = require("fs.util")

local ArchiveUtil = require("rizu.build.package.ArchiveUtil")
local RepoConfigWriter = require("rizu.build.package.RepoConfigWriter")

local _name = config.repo.name

---@class rizu.build.package.RepoAssembler
---@operator call: rizu.build.package.RepoAssembler
---@field ctx rizu.build.Context
---@field git_repo repo.CurrentRepo
---@field src_fs fs.IFilesystem
---@field config_writer rizu.build.package.RepoConfigWriter
local RepoAssembler = class()

---@param ctx rizu.build.Context
---@param git_repo repo.CurrentRepo
---@param src_fs? fs.IFilesystem
function RepoAssembler:new(ctx, git_repo, src_fs)
	self.ctx = ctx
	self.git_repo = git_repo
	self.src_fs = src_fs or ctx.fs
	self.config_writer = RepoConfigWriter(ctx, git_repo)
end

---@param gamerepo string
---@param root_prefix string
function RepoAssembler:validate(gamerepo, root_prefix)
	assert(self.ctx.fs:getInfo(gamerepo) ~= nil, "missing repo directory: " .. gamerepo)
	local game_love = gamerepo .. "/game.love"
	assert(self.ctx.fs:getInfo(game_love) ~= nil, "missing game.love: " .. game_love)

	local game_zip_listing = ArchiveUtil.getZipListing(self.ctx, game_love)
	assert(ArchiveUtil.hasEntry(game_zip_listing, "rizu/game/GameInteractor.lua"), "game.love is missing rizu/game/GameInteractor.lua")
	assert(ArchiveUtil.hasEntry(game_zip_listing, "conf.lua"), "game.love is missing conf.lua")
	assert(ArchiveUtil.hasEntry(game_zip_listing, "main.lua"), "game.love is missing main.lua")

	local lib_src = root_prefix .. "3rd-deps/lib/"
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

	local src_root = self.git_repo:getDirName()
	if src_root == "." then src_root = "" end
	local root_prefix = src_root == "" and "" or (src_root .. "/")

	print("Copying core folders...")
	for _, dir in ipairs(config.repo.include) do
		if self.src_fs:getInfo(root_prefix .. dir) then
			fs_util.copy(root_prefix .. dir, gamedir .. "/" .. dir, self.src_fs, self.ctx.fs)
		end
	end

	print("Copying root lua files...")
	local root_items_path = src_root == "" and "." or src_root
	if self.src_fs.tree then root_items_path = src_root end

	local root_items = self.src_fs:getDirectoryItems(root_items_path)
	for _, item in ipairs(root_items) do
		if item:match("%.lua$") then
			local info = self.src_fs:getInfo(root_prefix .. item)
			if info and info.type == "file" then
				fs_util.copy(root_prefix .. item, gamedir .. "/" .. item, self.src_fs, self.ctx.fs)
			end
		end
	end

	print("Copying 3rd-deps/lua...")
	self.ctx.fs:createDirectory(gamedir .. "/3rd-deps")
	if self.src_fs:getInfo(root_prefix .. "3rd-deps/lua") then
		fs_util.copy(root_prefix .. "3rd-deps/lua", gamedir .. "/3rd-deps/lua", self.src_fs, self.ctx.fs)
	end

	print("Extracting platform files...")
	for _, dir in ipairs(config.repo.extract) do
		if self.src_fs:getInfo(root_prefix .. dir) then
			fs_util.copy(root_prefix .. dir, gamerepo .. "/" .. dir, self.src_fs, self.ctx.fs)
		end
	end

	if self.src_fs:getInfo(root_prefix .. "3rd-deps/lib") then
		local libs = self.src_fs:getDirectoryItems(root_prefix .. "3rd-deps/lib")
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
				fs_util.copy(root_prefix .. "3rd-deps/lib/" .. lib, dst_dir .. "/" .. lib, self.src_fs, self.ctx.fs)
			end
		end
	end

	print("Cleaning up unnecessary files...")
	local to_delete = {}
	fs_util.find(gamedir, self.ctx.fs, function(path)
		if not path:match("%.lua$") and not path:match("%.c$") and not path:match("%.sql$") then
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

	if self.src_fs:getInfo(root_prefix .. "conf.lua") then
		fs_util.copy(root_prefix .. "conf.lua", gamerepo .. "/conf.lua", self.src_fs, self.ctx.fs)
	end
	if self.src_fs:getInfo("rizu/build/package/conf.lua") then
		fs_util.copy("rizu/build/package/conf.lua", gamerepo .. "/conf.lua", self.src_fs, self.ctx.fs)
	end

	self:validate(gamerepo, root_prefix)
end

return RepoAssembler
