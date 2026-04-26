local class = require("class")
local stbl = require("stbl")
local zlib = require("zlib")
local json = require("3rd-deps.lua.json")
local config = require("rizu.build.package.config")
local fs_util = require("fs.util")

local _name = config.repo.name

---@class repo.RepoBuilder
---@operator call: repo.RepoBuilder
---@field ctx rizu.build.Context
---@field git_repo repo.CurrentRepo
---@field src_fs fs.IFilesystem
local RepoBuilder = class()

---@param ctx rizu.build.Context
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

---@param listing string?
---@param path string
---@return boolean
local function hasArchiveEntry(listing, path)
	return listing ~= nil and listing:find(path, 1, true) ~= nil
end

---@param zip_path string
---@return string
function RepoBuilder:getZipListing(zip_path)
	local listing = self.ctx.shell:popen(string.format("unzip -l %q", zip_path))
	assert(listing and #listing > 0, "failed to read archive listing: " .. zip_path)
	return listing
end

---@param gamerepo string
---@param root_prefix string
function RepoBuilder:validateGenericRepo(gamerepo, root_prefix)
	assert(self.ctx.fs:getInfo(gamerepo) ~= nil, "missing repo directory: " .. gamerepo)
	local game_love = gamerepo .. "/game.love"
	assert(self.ctx.fs:getInfo(game_love) ~= nil, "missing game.love: " .. game_love)

	local game_zip_listing = self:getZipListing(game_love)
	assert(hasArchiveEntry(game_zip_listing, "rizu/game/GameInteractor.lua"), "game.love is missing rizu/game/GameInteractor.lua")
	assert(hasArchiveEntry(game_zip_listing, "conf.lua"), "game.love is missing conf.lua")
	assert(hasArchiveEntry(game_zip_listing, "main.lua"), "game.love is missing main.lua")

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
	self.ctx.shell:execute(string.format("bash -lc 'cd %q && zip -qry %q .'", gamedir, "../game.love"))
	fs_util.remove(gamedir, self.ctx.fs)

	if self.src_fs:getInfo(root_prefix .. "conf.lua") then
		fs_util.copy(root_prefix .. "conf.lua", gamerepo .. "/conf.lua", self.src_fs, self.ctx.fs)
	end
	if self.src_fs:getInfo("rizu/build/package/conf.lua") then
		fs_util.copy("rizu/build/package/conf.lua", gamerepo .. "/conf.lua", self.src_fs, self.ctx.fs)
	end

	self:validateGenericRepo(gamerepo, root_prefix)
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
	assert(self.ctx.fs:getInfo("build/repo/files.json") ~= nil, "missing files.json")
end

---@return nil
function RepoBuilder:build_zip()
	self.ctx.shell:execute(string.format("bash -lc 'cd %q && zip -qry %q %q'", "build/repo", _name .. ".zip", _name))
	local zip_path = "build/repo/" .. _name .. ".zip"
	assert(self.ctx.fs:getInfo(zip_path) ~= nil, "missing repo zip: " .. zip_path)
	local repo_zip_listing = self:getZipListing(zip_path)
	assert(hasArchiveEntry(repo_zip_listing, _name .. "/game.love"), "repo zip is missing " .. _name .. "/game.love")
end

---@return nil
function RepoBuilder:buildMacos()
	local game_app = "build/repo/macos/" .. _name .. ".app"
	local Contents = game_app .. "/Contents"
	local Frameworks = Contents .. "/Frameworks"
	local Resources = Contents .. "/Resources"

	local love_zip_path = "build/downloads/love-macos.zip"

	self.ctx.shell:execute(string.format("rm -rf %q", "build/repo/macos"))
	self.ctx.shell:execute(string.format("mkdir -p %q", "build/repo/macos"))

	if not self.ctx.fs:getInfo(love_zip_path) then
		print("Warning: " .. love_zip_path .. " not found, skipping macOS app build")
		return
	end
	self.ctx.shell:execute(string.format("unzip -oq %q -d %q", love_zip_path, "build/repo/macos"))
	if not self.ctx.fs:getInfo("build/repo/macos/love.app") then
		local nested_zip
		for _, item in ipairs(self.ctx.fs:getDirectoryItems("build/repo/macos")) do
			if item:match("%.zip$") then
				nested_zip = "build/repo/macos/" .. item
				break
			end
		end
		if nested_zip then
			self.ctx.shell:execute(string.format("unzip -oq %q -d %q", nested_zip, "build/repo/macos"))
			self.ctx.fs:remove(nested_zip)
		end
	end
	assert(self.ctx.fs:getInfo("build/repo/macos/love.app") ~= nil, "missing love.app in macOS runtime archive")
	self.ctx.shell:execute(string.format("mv %q %q", "build/repo/macos/love.app", game_app))
	self.ctx.shell:execute(string.format("find %q -type l -delete", game_app))
	if self.ctx.fs:getInfo(Frameworks) then
		self.ctx.shell:execute(string.format("find %q -type f -not -regex %q -delete", Frameworks, "^.*/A/[^/]*$"))
	end

	if self.src_fs:getInfo("rizu/build/package/Info.plist") then
		fs_util.copy("rizu/build/package/Info.plist", Contents .. "/Info.plist", self.src_fs, self.ctx.fs)
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

	self.ctx.shell:execute(string.format("find %q -empty -type d -delete", game_app))

	local macos_zip = "build/repo/" .. _name .. "_macos.zip"
	self.ctx.shell:execute(string.format("rm -f %q", macos_zip))
	self.ctx.shell:execute(string.format("bash -lc 'cd %q && zip -qry %q %q'", "build/repo/macos", "../" .. _name .. "_macos.zip", _name .. ".app"))
	assert(self.ctx.fs:getInfo(macos_zip) ~= nil, "missing macOS zip: " .. macos_zip)
	local mac_zip_listing = self:getZipListing(macos_zip)
	assert(hasArchiveEntry(mac_zip_listing, _name .. ".app/Contents/MacOS/love"), "macOS zip is missing app binary")
	assert(not hasArchiveEntry(mac_zip_listing, _name .. ".app/Contents/Frameworks/love.framework/Versions/A/Resources"), "framework resources were not pruned")
end

return RepoBuilder
