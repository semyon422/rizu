local class = require("class")

---@class build.tasks.Package
local Package = class()

function Package:new()
	self.name = "package"
	self.deps = {"build_linux", "build_windows"} 
end

function Package:run(ctx)
	local CurrentRepo = require("build.package.CurrentRepo")
	local RepoBuilder = require("build.package.RepoBuilder")
	local builder = RepoBuilder(ctx, CurrentRepo(ctx))
	builder:build_zip()
	builder:buildMacos()
end

function Package:getStatus(ctx)
	local res = {}
	table.insert(res, { name = "Package (rizu.zip)", value = ctx.fs:getInfo("build/repo/rizu.zip") and "OK" or "MISSING" })
	table.insert(res, { name = "Package (rizu_macos.zip)", value = ctx.fs:getInfo("build/repo/rizu_macos.zip") and "OK" or "MISSING" })
	return res
end

return Package
