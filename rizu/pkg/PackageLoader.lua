local path_util = require("path_util")
local aqua_pkg = require("pkg")
local class = require("class")
local json = require("json")
local Package = require("rizu.pkg.Package")

---@class rizu.PackageLoader
---@operator call: rizu.PackageLoader
local PackageLoader = class()

function PackageLoader:new()
	---@type {[string]: rizu.Package}
	self.packages = {}
	---@type {[string]: string}
	self.dirs = {}
	---@type {[string]: string}
	self.real_paths = {}
end

---@param paths string[]
---@param real_paths {[string]: string}?
function PackageLoader:load(paths, real_paths)
	self:new()
	for _, path in ipairs(paths) do
		local real_path = real_paths and real_paths[path]
		self:loadPackage(path, real_path)
	end
end

function PackageLoader:addLua()
	local pkgs = self:getPackages()
	for _, pkg in ipairs(pkgs) do
		local path = self.dirs[pkg.name]
		aqua_pkg.add(path)
	end
	aqua_pkg.export_lua()
	aqua_pkg.export_love()
end

function PackageLoader:removeLua()
	local pkgs = self:getPackages()
	for _, pkg in ipairs(pkgs) do
		local path = self.dirs[pkg.name]
		aqua_pkg.remove(path)
	end
	aqua_pkg.export_lua()
	aqua_pkg.export_love()
end

---@return rizu.Package[]
function PackageLoader:getPackages()
	---@type rizu.Package[]
	local pkgs = {}
	for _, pkg in pairs(self.packages) do
		table.insert(pkgs, pkg)
	end
	table.sort(pkgs, function(a, b)
		return a.name < b.name
	end)
	return pkgs
end

---@param _type string
---@return rizu.Package[]
function PackageLoader:getPackagesByType(_type)
	---@type rizu.Package[]
	local pkgs = {}
	for _, pkg in pairs(self:getPackages()) do
		if pkg.types[_type] then
			table.insert(pkgs, pkg)
		end
	end
	return pkgs
end

---@param path string
---@param real_path string?
---@private
function PackageLoader:loadPackage(path, real_path)
	local root_path = self:lookupRootDir(path)
	if not root_path then
		return
	end

	local metadata_path = path_util.join(root_path, "pkg.json")
	local data = love.filesystem.read(metadata_path)

	local pkg = Package(json.decode(data))
	local name = pkg.name

	local existing_pkg = self.packages[name]
	if existing_pkg then
		error(("package '%s' duplicate:\n%s\n%s"):format(
			name,
			real_path,
			self.real_paths[name]
		))
		return
	end

	self.packages[name] = pkg
	self.dirs[name] = root_path
	self.real_paths[name] = real_path

	print("package loaded: " .. name)
end

---@param dir string
---@return string?
---@private
function PackageLoader:lookupRootDir(dir)
	local path = path_util.join(dir, "pkg.json")
	if love.filesystem.getInfo(path, "file") then
		return dir
	end

	---@type string[]
	local items = love.filesystem.getDirectoryItems(dir)
	for _, item in ipairs(items) do
		local _dir = path_util.join(dir, item)
		local _path = path_util.join(dir, item, "pkg.json")
		local dir_info = love.filesystem.getInfo(_dir, "directory")
		local file_info = love.filesystem.getInfo(_path, "file")
		if dir_info and file_info then
			return _dir
		end
	end
end

return PackageLoader
