local ITask = require("rizu.build.ITask")

---@class rizu.build.tasks.AssembleRepoTask: rizu.build.ITask
---@operator call: rizu.build.tasks.AssembleRepoTask
---@field name string
---@field deps string[]
local AssembleRepoTask = ITask + {}

function AssembleRepoTask:new()
	self.name = "assemble_repo"
	self.deps = {"build_target_linux", "build_target_windows", "build_target_macos"}
end

---@param ctx rizu.build.Context
function AssembleRepoTask:run(ctx)
	local CurrentRepo = require("rizu.build.package.CurrentRepo")
	local RepoBuilder = require("rizu.build.package.RepoBuilder")
	local builder = RepoBuilder(ctx, CurrentRepo(ctx))
	builder:build()
end

---@param ctx rizu.build.Context
---@return rizu.build.StatusRow[]
function AssembleRepoTask:getStatus(ctx)
	return {
		{name = "Update Repo (files.json)", value = ctx.fs:getInfo("build/repo/files.json") and "OK" or "MISSING"},
	}
end

return AssembleRepoTask
