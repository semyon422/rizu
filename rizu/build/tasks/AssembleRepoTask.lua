local ITask = require("rizu.build.ITask")
local config = require("rizu.build.package.config")
local CurrentRepo = require("rizu.build.package.CurrentRepo")
local RepoAssembler = require("rizu.build.package.RepoAssembler")
local UpdateIndexWriter = require("rizu.build.package.UpdateIndexWriter")

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
	RepoAssembler(ctx, CurrentRepo(ctx)):build()
	UpdateIndexWriter(ctx):write("build/repo/" .. config.repo.name)
end

---@param ctx rizu.build.Context
---@return rizu.build.StatusRow[]
function AssembleRepoTask:getStatus(ctx)
	return {
		{name = "Update Repo (files.json)", value = ctx.fs:getInfo("build/repo/files.json") and "OK" or "MISSING"},
	}
end

return AssembleRepoTask
