local ITask = require("rizu.build.ITask")
local MacOSPackager = require("rizu.build.package.MacOSPackager")

---@class rizu.build.tasks.PackageMacOSTask: rizu.build.ITask
---@operator call: rizu.build.tasks.PackageMacOSTask
---@field name string
---@field deps string[]
local PackageMacOSTask = ITask + {}

function PackageMacOSTask:new()
	self.name = "package_macos"
	self.deps = {"assemble_repo"}
end

---@param ctx rizu.build.Context
function PackageMacOSTask:run(ctx)
	MacOSPackager(ctx):build()
end

---@param ctx rizu.build.Context
---@return rizu.build.StatusRow[]
function PackageMacOSTask:getStatus(ctx)
	return {
		{name = "Package (rizu_macos.zip)", value = ctx.fs:getInfo("build/repo/rizu_macos.zip") and "OK" or "MISSING"},
	}
end

return PackageMacOSTask
