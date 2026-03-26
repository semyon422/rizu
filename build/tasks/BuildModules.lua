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
	local bin_dir_map = {
		linux   = "bin/linux64",
		windows = "bin/win64",
		macos   = "bin/mac64",
	}
	local ext_map = {
		linux   = "so",
		windows = "dll",
		macos   = "dylib",
	}
	
	local bin_dir = bin_dir_map[target] or bin_dir_map.linux
	local ext = ext_map[target] or ext_map.linux
	
	local modules = {"video", "lib7z", "minacalc", "luamidi"}
	if target == "windows" then modules = {"video", "7z", "minacalc", "luamidi"} end
	
	for _, mod in ipairs(modules) do
		local m_ext = ext
		if target == "macos" and mod == "video" then m_ext = "so" end
		if target == "macos" and mod == "minacalc" then m_ext = "dylib" end -- libminacalc.dylib
		
		local name = mod
		if mod == "minacalc" and target ~= "windows" then name = "libminacalc" end
		if mod == "luamidi" and target == "macos" then name = "luamidi" end -- luamidi.dylib ? 
		
		local bin_path = bin_dir .. "/" .. name .. "." .. m_ext
		local src_path = "aqua/" .. mod:gsub("^lib", "") .. ".c"
		if mod == "minacalc" or mod == "luamidi" then
			src_path = "build/deps/" .. mod
		end
		
		local bin_info = ctx.fs:getInfo(bin_path)
		local src_info = ctx.fs:getInfo(src_path)
		
		if not bin_info or not src_info then return false end
		if bin_info.modtime < src_info.modtime then return false end
	end
	
	return true
end

function BuildModules:getStatus(ctx)
	local target = self.target:lower()
	local bin_dir_map = {
		linux   = "bin/linux64",
		windows = "bin/win64",
		macos   = "bin/mac64",
	}
	local ext_map = {
		linux   = "so",
		windows = "dll",
		macos   = "dylib",
	}
	
	local bin_dir = bin_dir_map[target] or bin_dir_map.linux
	local ext = ext_map[target] or ext_map.linux
	
	local modules = {"video", "lib7z", "minacalc", "luamidi"}
	if target == "windows" then modules = {"video", "7z", "minacalc", "luamidi"} end
	
	local res = {}
	for _, mod in ipairs(modules) do
		local m_ext = ext
		if target == "macos" and mod == "video" then m_ext = "so" end
		if target == "macos" and mod == "minacalc" then m_ext = "dylib" end
		
		local name = mod
		if mod == "minacalc" and target ~= "windows" then name = "libminacalc" end
		if mod == "luamidi" and target == "macos" then name = "luamidi" end
		
		local bin_path = bin_dir .. "/" .. name .. "." .. m_ext
		local src_path = "aqua/" .. mod:gsub("^lib", "") .. ".c"
		if mod == "minacalc" or mod == "luamidi" then
			src_path = "build/deps/" .. mod
		end

		local bin_info = ctx.fs:getInfo(bin_path)

		local src_info = ctx.fs:getInfo(src_path)
		
		local status = "MISSING"
		if bin_info and src_info then
			status = bin_info.modtime >= src_info.modtime and "OK" or "OUTDATED"
		elseif bin_info then
			status = "OK"
		end
		
		table.insert(res, { name = mod .. " (" .. target .. ")", value = status })
	end
	
	return res
end

return BuildModules
