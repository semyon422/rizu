local ITask = require("build.ITask")

---@class build.tasks.BuildRepoTask: build.ITask
---@operator call: build.tasks.BuildRepoTask
---@field name string
---@field deps string[]
local BuildRepoTask = ITask + {}

function BuildRepoTask:new()
	self.name = "repo"
	self.deps = {"pipeline_linux", "pipeline_windows", "pipeline_macos"}
end

---@param ctx build.Context
function BuildRepoTask:run(ctx)
	local CurrentRepo = require("build.package.CurrentRepo")
	local RepoBuilder = require("build.package.RepoBuilder")
	local builder = RepoBuilder(ctx, CurrentRepo(ctx))
	builder:build()
	builder:build_zip()
	builder:buildMacos()
end

---@param ctx build.Context
---@return build.StatusRow[]
function BuildRepoTask:getStatus(ctx)
	local res = {}
	table.insert(res, {name = "Update Repo (files.json)", value = ctx.fs:getInfo("build/repo/files.json") and "OK" or "MISSING"})
	return res
end

return BuildRepoTask
