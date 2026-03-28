local class = require("class")
local stbl = require("stbl")
local zlib = require("zlib")
local json = require("3rd-deps.lua.json")
local config = require("build.package.config")
local fs_util = require("fs.util")
local ZipFilesystem = require("fs.ZipFilesystem")

local _name = config.repo.name

---@class repo.RepoBuilder
---@operator call: repo.RepoBuilder
---@field ctx build.Context
---@field git_repo repo.CurrentRepo
---@field src_fs fs.IFilesystem
local RepoBuilder = class()

---@param ctx build.Context
---@param git_repo repo.CurrentRepo
---@param src_fs? fs.IFilesystem
function RepoBuilder:new(ctx, git_repo, src_fs)
	self.ctx = ctx
	self.git_repo = git_repo
	self.src_fs = src_fs or ctx.fs
end

local function serialize(t)
	return ("return %s\n"):format(stbl.encode(t))
end

---@param gamedir string
function RepoBuilder:writeConfigs(gamedir)
	self.ctx.fs:write(gamedir .. "/version.lua", serialize({
		date = self.git_repo:log_date(),
		commit = self.git_repo:log_commit(),
	}))

	local urls_path = gamedir .. "/sphere/persistence/ConfigModel/urls.lua"
	-- URLs path should exist in the target directory (gamedir) which is in ctx.fs
	local content = self.ctx.fs:read(urls_path)
	if content then
		local chunk = loadstring(content)
		if chunk then
			local urls = chunk()
			urls.host = config.game.api
			urls.websocket = config.game.websocket
			urls.update = config.game.repo .. "/files.json"
			urls.osu = config.osu
			urls.multiplayer = config.game.multiplayer
			self.ctx.fs:write(urls_path, serialize(urls))
		end
	end
end

---@return nil
function RepoBuilder:buildGenericRepo()
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
	if self.src_fs.tree then root_items_path = src_root end -- Handle FakeFilesystem

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

	self:writeConfigs(gamedir)

	print("Zipping game.love...")
	local zfs = ZipFilesystem()
	fs_util.copy(gamedir, "", self.ctx.fs, zfs)
	self.ctx.fs:write(gamerepo .. "/game.love", zfs:save())
	fs_util.remove(gamedir, self.ctx.fs)

	if self.src_fs:getInfo(root_prefix .. "conf.lua") then
		fs_util.copy(root_prefix .. "conf.lua", gamerepo .. "/conf.lua", self.src_fs, self.ctx.fs)
	end
	if self.src_fs:getInfo("build/package/conf.lua") then
		fs_util.copy("build/package/conf.lua", gamerepo .. "/conf.lua", self.src_fs, self.ctx.fs)
	end
end

---@return nil
function RepoBuilder:build()
	self:buildGenericRepo()

	local gamerepo = "build/repo/" .. _name
	local files = {}
	fs_util.find(gamerepo, self.ctx.fs, function(path)
		local content = self.ctx.fs:read(path)
		if content then
			local rel_path = path:sub(#gamerepo + 2)
			table.insert(files, {
				path = rel_path,
				url = config.game.repo .. "/" .. rel_path,
				hash = zlib.crc32(0, content),
			})
		end
	end)

	self.ctx.fs:createDirectory(gamerepo .. "/userdata")
	self.ctx.fs:write(gamerepo .. "/userdata/files.lua", serialize(files))
	self.ctx.fs:write("build/repo/files.json", json.encode(files))
end

---@return nil
function RepoBuilder:build_zip()
	local gamerepo = "build/repo/" .. _name
	local zfs = ZipFilesystem()
	fs_util.copy(gamerepo, _name, self.ctx.fs, zfs)
	self.ctx.fs:write("build/repo/" .. _name .. ".zip", zfs:save())
end

---@return nil
function RepoBuilder:update_zip()
	local zip_path = "build/repo/" .. _name .. ".zip"
	local zip_data = self.ctx.fs:read(zip_path)
	if not zip_data then return end

	local zfs = ZipFilesystem(zip_data)
	local gamelove = self.ctx.fs:read("build/repo/" .. _name .. "/game.love")
	if gamelove then
		zfs:write(_name .. "/game.love", gamelove)
		self.ctx.fs:write(zip_path, zfs:save())
	end
end

---@return nil
function RepoBuilder:buildMacos()
	local game_app = "build/repo/macos/" .. _name .. ".app"
	local Contents = game_app .. "/Contents"
	local Frameworks = Contents .. "/Frameworks"
	local Resources = Contents .. "/Resources"

	fs_util.remove("build/repo/macos", self.ctx.fs)
	self.ctx.fs:createDirectory("build/repo/macos")

	local love_zip_path = "build/downloads/love-macos.zip"
	local love_zip_data = self.src_fs:read(love_zip_path)
	if not love_zip_data then
		print("Warning: " .. love_zip_path .. " not found, skipping macOS app build")
		return
	end

	local src_zfs = ZipFilesystem(love_zip_data)
	fs_util.copy("love.app", game_app, src_zfs, self.ctx.fs)

	local to_delete = {}
	fs_util.find(Frameworks, self.ctx.fs, function(path)
		if not path:match("/A/[^/]+$") then
			table.insert(to_delete, path)
		end
	end)
	for _, path in ipairs(to_delete) do self.ctx.fs:remove(path) end

	if self.src_fs:getInfo("build/package/Info.plist") then
		fs_util.copy("build/package/Info.plist", Contents .. "/Info.plist", self.src_fs, self.ctx.fs)
	end

	fs_util.remove(Resources, self.ctx.fs)
	fs_util.copy("build/repo/" .. _name, Resources, self.ctx.fs, self.ctx.fs)

	if self.ctx.fs:getInfo(Resources .. "/bin/mac64") then
		local mac64_files = {}
		fs_util.find(Resources .. "/bin/mac64", self.ctx.fs, function(p) table.insert(mac64_files, p) end)
		for _, path in ipairs(mac64_files) do
			local name = path:match("([^/]+)$")
			fs_util.copy(path, Frameworks .. "/" .. name, self.ctx.fs, self.ctx.fs)
			self.ctx.fs:remove(path)
		end
	end

	fs_util.remove(Resources .. "/bin/win64", self.ctx.fs)
	fs_util.remove(Resources .. "/bin/linux64", self.ctx.fs)

	fs_util.removeEmptyDirs(game_app, self.ctx.fs)

	local dst_zfs = ZipFilesystem()
	fs_util.copy(game_app, _name .. ".app", self.ctx.fs, dst_zfs)
	self.ctx.fs:write("build/repo/" .. _name .. "_macos.zip", dst_zfs:save())
end

return RepoBuilder
