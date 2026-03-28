local class = require("class")
local Builder = require("build.Builder")
local BuildConfig = require("build.BuildConfig")

---@class build.tasks.SyncBinaries
local SyncBinaries = class()

function SyncBinaries:new(target)
	self.name = "sync_" .. target
	self.target = target
	self.deps = {"build_" .. target}
end

function SyncBinaries:run(ctx)
	local builder = Builder(ctx, self.target)
	builder:syncMissingToBin()
end

function SyncBinaries:upToDate(ctx)
	local builder = Builder(ctx, self.target)
	local t = self.target:lower()
	local out = builder:getModuleOutputs()
	local bin_dir = BuildConfig.getBinDir(t)
	local expected = BuildConfig.getModuleRecords(t, out, bin_dir)

	for _, item in ipairs(expected) do
		if item.artifact and ctx.fs:getInfo(item.artifact) and not ctx.fs:getInfo(item.bin) then
			return false
		end
	end

	return true
end

function SyncBinaries:getStatus(ctx)
	local t = self.target:lower()
	local builder = Builder(ctx, self.target)
	local out = builder:getModuleOutputs()
	local bin_dir = BuildConfig.getBinDir(t)
	local expected = BuildConfig.getModuleRecords(t, out, bin_dir)

	local missing = 0
	for _, item in ipairs(expected) do
		if item.artifact and ctx.fs:getInfo(item.artifact) and not ctx.fs:getInfo(item.bin) then
			missing = missing + 1
		end
	end

	local value = missing == 0 and "OK" or ("MISSING " .. tostring(missing))
	return {{ name = "Bin Sync (" .. t .. ")", value = value }}
end

return SyncBinaries
