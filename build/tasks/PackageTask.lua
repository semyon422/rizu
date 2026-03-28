local ITask = require("build.ITask")

---@class build.tasks.PackageTask: build.ITask
---@operator call: build.tasks.PackageTask
---@field name string
---@field deps string[]
local PackageTask = ITask + {}

function PackageTask:new()
	self.name = "package"
	self.deps = {"pipeline_linux", "pipeline_windows", "pipeline_macos"}
end

---@param ctx build.Context
function PackageTask:run(ctx)
	local CurrentRepo = require("build.package.CurrentRepo")
	local RepoBuilder = require("build.package.RepoBuilder")
	local builder = RepoBuilder(ctx, CurrentRepo(ctx))
	builder:build_zip()
	builder:buildMacos()
end

---@param ctx build.Context
---@return build.StatusRow[]
function PackageTask:getStatus(ctx)
	local res = {}
	table.insert(res, {name = "Package (rizu.zip)", value = ctx.fs:getInfo("build/repo/rizu.zip") and "OK" or "MISSING"})
	table.insert(res, {name = "Package (rizu_macos.zip)", value = ctx.fs:getInfo("build/repo/rizu_macos.zip") and "OK" or "MISSING"})
	return res
end

return PackageTask
