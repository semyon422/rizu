local class = require("class")
local Builder = require("build.Builder")
local BuildConfig = require("build.BuildConfig")

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
	local records = BuildConfig.getModuleRecords(target, builder:getModuleOutputs(), BuildConfig.getBinDir(target))

	for _, mod in ipairs(records) do
		if mod.key == "video" and not should_check_video(ctx, target) then
			goto continue
		end

		local bin_info = ctx.fs:getInfo(mod.artifact)
		local src_info = ctx.fs:getInfo(mod.source)
		
		if not bin_info or not src_info then return false end
		if bin_info.modtime < src_info.modtime then return false end

		::continue::
	end
	
	return true
end

function BuildModules:getStatus(ctx)
	local target = self.target:lower()
	local builder = Builder(ctx, target)
	local records = BuildConfig.getModuleRecords(target, builder:getModuleOutputs(), BuildConfig.getBinDir(target))

	local res = {}
	for _, mod in ipairs(records) do
		local name = BuildConfig.getModuleStatusName(target, mod.key)
		if mod.key == "video" and not should_check_video(ctx, target) then
			table.insert(res, { name = name .. " (" .. target .. ")", value = "SKIPPED (no ffmpeg)" })
			goto continue
		end

		local bin_info = ctx.fs:getInfo(mod.artifact)
		local src_info = ctx.fs:getInfo(mod.source)
		
		local status = "MISSING"
		if bin_info and src_info then
			status = bin_info.modtime >= src_info.modtime and "OK" or "OUTDATED"
		elseif bin_info then
			status = "OK"
		end
		
		table.insert(res, { name = name .. " (" .. target .. ")", value = status })

		::continue::
	end
	
	return res
end

return BuildModules
