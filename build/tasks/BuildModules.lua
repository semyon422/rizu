local class = require("class")
local Builder = require("build.Builder")

---@class build.tasks.BuildModules
local BuildModules = class()

function BuildModules:new(target)
	self.name = "build_" .. target
	self.target = target
	self.deps = {"deps_" .. target}
end

function BuildModules:run(ctx)
	local builder = Builder(ctx)
	builder:run()
end

function BuildModules:upToDate(ctx)
	-- Incremental build logic
	local target = self.target:lower()
	local bin_dir = "bin/" .. (target == "linux" and "linux64" or "win64")
	local ext = (target == "linux" and "so" or "dll")
	
	local modules = {"video", "lib7z"}
	if target == "windows" or target == "win64" then modules = {"video", "7z"} end
	
	for _, mod in ipairs(modules) do
		local bin_path = bin_dir .. "/" .. mod .. "." .. ext
		local src_path = "aqua/" .. mod:gsub("^lib", "") .. ".c"
		
		local bin_info = ctx.fs:getInfo(bin_path)
		local src_info = ctx.fs:getInfo(src_path)
		
		if not bin_info or not src_info then return false end
		if bin_info.modtime < src_info.modtime then return false end
	end
	
	return true
end

return BuildModules
