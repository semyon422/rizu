local class = require("class")
local Builder = require("build.Builder")

---@class build.tasks.BuildModules
local BuildModules = class()

local function should_check_video(ctx, target)
	if target ~= "macos" then
		return true
	end
	local builder = Builder(ctx, target)
	local ffmpeg_inc = builder:getFFmpegPaths()
	return ffmpeg_inc ~= nil
end

function BuildModules:new(target)
	self.name = "build_" .. target
	self.target = target
	self.deps = {"deps_" .. target}
end

function BuildModules:run(ctx)
	local builder = Builder(ctx, self.target)
	builder:run()
end

function BuildModules:upToDate(ctx)
	-- Incremental build logic
	local target = self.target:lower()
	local builder = Builder(ctx, target)
	local out = builder:getModuleOutputs()
	
	local modules = {"video", "lib7z", "minacalc", "luamidi"}
	if target == "windows" then modules = {"video", "7z", "minacalc", "luamidi"} end
	
	for _, mod in ipairs(modules) do
		if mod == "video" and not should_check_video(ctx, target) then
			goto continue
		end

		local bin_path
		if mod == "video" then
			bin_path = out.video
		elseif mod == "minacalc" then
			bin_path = out.minacalc
		elseif mod == "luamidi" then
			bin_path = out.luamidi
		else
			bin_path = out.z7
		end
		local src_path = "aqua/" .. mod:gsub("^lib", "") .. ".c"
		if mod == "minacalc" or mod == "luamidi" then
			src_path = "build/deps/" .. mod
		end
		
		local bin_info = ctx.fs:getInfo(bin_path)
		local src_info = ctx.fs:getInfo(src_path)
		
		if not bin_info or not src_info then return false end
		if bin_info.modtime < src_info.modtime then return false end

		::continue::
	end
	
	return true
end

function BuildModules:getStatus(ctx)
	local target = self.target:lower()
	local builder = Builder(ctx, target)
	local out = builder:getModuleOutputs()
	
	local modules = {"video", "lib7z", "minacalc", "luamidi"}
	if target == "windows" then modules = {"video", "7z", "minacalc", "luamidi"} end
	
	local res = {}
	for _, mod in ipairs(modules) do
		if mod == "video" and not should_check_video(ctx, target) then
			table.insert(res, { name = mod .. " (" .. target .. ")", value = "SKIPPED (no ffmpeg)" })
			goto continue
		end

		local bin_path
		if mod == "video" then
			bin_path = out.video
		elseif mod == "minacalc" then
			bin_path = out.minacalc
		elseif mod == "luamidi" then
			bin_path = out.luamidi
		else
			bin_path = out.z7
		end
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

		::continue::
	end
	
	return res
end

return BuildModules
