local ITask = require("rizu.build.ITask")
local ZipPackager = require("rizu.build.package.ZipPackager")

---@class rizu.build.tasks.ZipRepoTask: rizu.build.ITask
---@operator call: rizu.build.tasks.ZipRepoTask
---@field name string
---@field deps string[]
local ZipRepoTask = ITask + {}

function ZipRepoTask:new()
	self.name = "zip_repo"
	self.deps = {"assemble_repo"}
end

---@param ctx rizu.build.Context
function ZipRepoTask:run(ctx)
	ZipPackager(ctx):build()
end

---@param ctx rizu.build.Context
---@return rizu.build.StatusRow[]
function ZipRepoTask:getStatus(ctx)
	return {
		{name = "Package (rizu.zip)", value = ctx.fs:getInfo("build/repo/rizu.zip") and "OK" or "MISSING"},
	}
end

return ZipRepoTask
