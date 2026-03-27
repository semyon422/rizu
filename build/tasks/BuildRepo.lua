local class = require("class")

---@class build.tasks.BuildRepo
local BuildRepo = class()

function BuildRepo:new()
	self.name = "repo"
	self.deps = {"build_linux", "build_windows", "build_macos"}
end

function BuildRepo:run(ctx)
	local CurrentRepo = require("build.package.CurrentRepo")
	local RepoBuilder = require("build.package.RepoBuilder")
	local builder = RepoBuilder(ctx, CurrentRepo(ctx))
	builder:build()
	builder:build_zip()
	builder:buildMacos()
end

function BuildRepo:getStatus(ctx)
	local res = {}
	table.insert(res, { name = "Update Repo (files.json)", value = ctx.fs:getInfo("build/repo/files.json") and "OK" or "MISSING" })
	return res
end

return BuildRepo
