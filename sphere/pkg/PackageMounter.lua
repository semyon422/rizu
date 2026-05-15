local path_util = require("path_util")
local class = require("class")

---@class sphere.PackageMounter
---@operator call: sphere.PackageMounter
---@field paths string[]
---@field real_paths {[string]: string}
local PackageMounter = class()

PackageMounter.mount_path = "pkg_mount"

function PackageMounter:new()
	self.mount_index = 0
	self.paths = {}
	self.real_paths = {}
end

---@param path string
---@return string?
function PackageMounter:getFullPath(path)
	local real_dir = love.filesystem.getRealDirectory(path)
	if not real_dir then
		return
	end
	return path_util.join(real_dir, path)
end

---@param pkgs_path string
function PackageMounter:mount(pkgs_path)
	---@type string[]
	local items = love.filesystem.getDirectoryItems(pkgs_path)

	for _, item in ipairs(items) do
		self.mount_index = self.mount_index + 1
		local path = path_util.join(pkgs_path, item)
		local info = love.filesystem.getInfo(path)

		local mount_path = path_util.join(self.mount_path, self.mount_index)
		if info.type == "directory" or info.type == "symlink" or
			(info.type == "file" and item:match("%.zip$"))
		then
			local full_path = self:getFullPath(path)
			local ok = full_path and love.filesystem.mountFullPath(full_path, mount_path, "read", false)
			if not ok then
				print("failed to mount package path", path)
			else
				self.real_paths[mount_path] = full_path
				table.insert(self.paths, mount_path)
			end
		end
	end
end

function PackageMounter:unmount()
	for mount_path, full_path in pairs(self.real_paths) do
		local ok = love.filesystem.unmountFullPath(full_path)
		if not ok then
			print("failed to unmount package path", mount_path)
		else
			self.real_paths[mount_path] = nil
		end
	end
	self.real_paths = {}
	self.paths = {}
end

return PackageMounter
