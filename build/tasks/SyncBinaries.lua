local class = require("class")
local Builder = require("build.Builder")

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
	local bin_dir_map = {
		linux = "bin/linux64",
		windows = "bin/win64",
		macos = "bin/mac64",
	}
	local bin_dir = bin_dir_map[t] or bin_dir_map.linux

	local expected = {
		{src = out.z7, dst = (t == "windows") and (bin_dir .. "/7z.dll") or (t == "macos" and (bin_dir .. "/lib7z.dylib") or (bin_dir .. "/lib7z.so"))},
		{src = out.video, dst = (t == "windows") and (bin_dir .. "/video.dll") or (bin_dir .. "/video.so")},
		{src = out.minacalc, dst = (t == "windows") and (bin_dir .. "/minacalc.dll") or (t == "macos" and (bin_dir .. "/libminacalc.dylib") or (bin_dir .. "/libminacalc.so"))},
		{src = out.luamidi, dst = (t == "windows") and (bin_dir .. "/luamidi.dll") or (t == "macos" and (bin_dir .. "/luamidi.dylib") or (bin_dir .. "/luamidi.so"))},
	}

	for _, item in ipairs(expected) do
		if item.src and ctx.fs:getInfo(item.src) and not ctx.fs:getInfo(item.dst) then
			return false
		end
	end

	return true
end

function SyncBinaries:getStatus(ctx)
	local t = self.target:lower()
	local builder = Builder(ctx, self.target)
	local out = builder:getModuleOutputs()
	local bin_dir_map = {
		linux = "bin/linux64",
		windows = "bin/win64",
		macos = "bin/mac64",
	}
	local bin_dir = bin_dir_map[t] or bin_dir_map.linux

	local expected = {
		{src = out.z7, dst = (t == "windows") and (bin_dir .. "/7z.dll") or (t == "macos" and (bin_dir .. "/lib7z.dylib") or (bin_dir .. "/lib7z.so"))},
		{src = out.video, dst = (t == "windows") and (bin_dir .. "/video.dll") or (bin_dir .. "/video.so")},
		{src = out.minacalc, dst = (t == "windows") and (bin_dir .. "/minacalc.dll") or (t == "macos" and (bin_dir .. "/libminacalc.dylib") or (bin_dir .. "/libminacalc.so"))},
		{src = out.luamidi, dst = (t == "windows") and (bin_dir .. "/luamidi.dll") or (t == "macos" and (bin_dir .. "/luamidi.dylib") or (bin_dir .. "/luamidi.so"))},
	}

	local missing = 0
	for _, item in ipairs(expected) do
		if item.src and ctx.fs:getInfo(item.src) and not ctx.fs:getInfo(item.dst) then
			missing = missing + 1
		end
	end

	local value = missing == 0 and "OK" or ("MISSING " .. tostring(missing))
	return {{ name = "Bin Sync (" .. t .. ")", value = value }}
end

return SyncBinaries
