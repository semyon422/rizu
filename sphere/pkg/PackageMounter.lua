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
			local ok = love.filesystem.mount(path, mount_path, false)
			if not ok then
				print("failed to mount package path", path)
			else
				self.real_paths[mount_path] = path
				table.insert(self.paths, mount_path)
			end
		end
	end
end

function PackageMounter:unmount()
	for path in pairs(self.real_paths) do
		local ok = love.filesystem.unmount(path)
		if not ok then
			print("failed to unmount package path", path)
		else
			self.real_paths[path] = nil
		end
	end
	self.real_paths = {}
	self.paths = {}
end

return PackageMounter
