local class = require("class")
local config = require("rizu.build.package.config")
local fs_util = require("fs.util")

local ArchiveUtil = require("rizu.build.package.ArchiveUtil")

local _name = config.repo.name

---@class rizu.build.package.MacOSPackager
---@operator call: rizu.build.package.MacOSPackager
---@field ctx rizu.build.Context
---@field src_fs fs.IFilesystem
local MacOSPackager = class()

local function quote(s)
	return string.format("%q", s)
end

---@param path string
---@return string
function MacOSPackager.getPortableLibraryName(path)
	local name = assert(path:match("([^/]+)$"))
	return (name:gsub("%.[0-9][0-9%.]*%.dylib$", ".dylib"))
end

---@param ctx rizu.build.Context
---@param src_fs? fs.IFilesystem
function MacOSPackager:new(ctx, src_fs)
	self.ctx = ctx
	self.src_fs = src_fs or ctx.fs
end

---@param name string
---@return string
function MacOSPackager:findMacOSTool(name)
	local tool = self.ctx.shell:popen("command -v " .. name)
	if tool and tool:match("%S") then
		return assert(tool:match("^%s*(.-)%s*$"))
	end

	tool = self.ctx.shell:popen("find build/deps/osxcross/target/bin -type f -name '*-" .. name .. "' | head -n 1")
	assert(tool and tool:match("%S"), "missing macOS packaging tool: " .. name)
	return assert(tool:match("^%s*(.-)%s*$"))
end

---@param Frameworks string
function MacOSPackager:makeLibrariesPortable(Frameworks)
	local install_name_tool = self:findMacOSTool("install_name_tool")
	local otool = self:findMacOSTool("otool")
	local files = assert(self.ctx.shell:popen("find " .. quote(Frameworks) .. " -type f"))

	---@type {[string]: string}
	local libraries = {}
	for path in files:gmatch("[^\n]+") do
		local name = path:match("([^/]+)$")
		if name and name:match("%.dylib$") then
			libraries[name] = path
		end
	end

	for binary in files:gmatch("[^\n]+") do
		local dependencies = self.ctx.shell:popen(quote(otool) .. " -L " .. quote(binary))
		if dependencies and dependencies:match("build/deps/") then
			for dependency in dependencies:gmatch("([^%s]+build/deps/[^%s]+)") do
				local name = self.getPortableLibraryName(dependency)
				assert(libraries[name], "missing bundled macOS dependency: " .. name)
				self.ctx.shell:execute(quote(install_name_tool) .. " -change " .. quote(dependency) .. " " .. quote("@loader_path/" .. name) .. " " .. quote(binary))
			end
		end

		local install_id = self.ctx.shell:popen(quote(otool) .. " -D " .. quote(binary))
		local id = install_id and install_id:match("\n([^\n]+)")
		if id and id:match("build/deps/") then
			local name = assert(binary:match("([^/]+)$"))
			self.ctx.shell:execute(quote(install_name_tool) .. " -id " .. quote("@loader_path/" .. name) .. " " .. quote(binary))
		end
	end

	for binary in files:gmatch("[^\n]+") do
		local dependencies = self.ctx.shell:popen(quote(otool) .. " -L " .. quote(binary))
		assert(not dependencies or not dependencies:match("build/deps/"), "macOS binary contains a build-host dependency: " .. binary)
	end
end

function MacOSPackager:build()
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
		---@type string?
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
		---@type string[]
		local mac64_files = {}
		fs_util.find(Resources .. "/bin/mac64", self.ctx.fs, function(p) table.insert(mac64_files, p) end)
		for _, path in ipairs(mac64_files) do
			local name = assert(path:match("([^/]+)$"))
			fs_util.copy(path, Frameworks .. "/" .. name, self.ctx.fs, self.ctx.fs)
			self.ctx.fs:remove(path)
		end
	end

	self:makeLibrariesPortable(Frameworks)

	fs_util.remove(Resources .. "/bin/win64", self.ctx.fs)
	fs_util.remove(Resources .. "/bin/linux64", self.ctx.fs)

	self.ctx.shell:execute(string.format("find %q -empty -type d -delete", game_app))

	local macos_zip = "build/repo/" .. _name .. "_macos.zip"
	self.ctx.shell:execute(string.format("rm -f %q", macos_zip))
	self.ctx.shell:execute(string.format("bash -lc 'cd %q && zip -qry %q %q'", "build/repo/macos", "../" .. _name .. "_macos.zip", _name .. ".app"))
	assert(self.ctx.fs:getInfo(macos_zip) ~= nil, "missing macOS zip: " .. macos_zip)
	local mac_zip_listing = ArchiveUtil.getZipListing(self.ctx, macos_zip)
	assert(ArchiveUtil.hasEntry(mac_zip_listing, _name .. ".app/Contents/MacOS/love"), "macOS zip is missing app binary")
	assert(not ArchiveUtil.hasEntry(mac_zip_listing, _name .. ".app/Contents/Frameworks/love.framework/Versions/A/Resources"), "framework resources were not pruned")
end

return MacOSPackager
