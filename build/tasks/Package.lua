local class = require("class")

---@class build.tasks.Package
local Package = class()

function Package:new()
	self.name = "package"
	-- In theory package needs all builds, but let's assume current target
	self.deps = {} 
end

function Package:run(ctx)
	local CurrentRepo = require("build.package.CurrentRepo")
	local RepoBuilder = require("build.package.RepoBuilder")
	local builder = RepoBuilder(CurrentRepo())
	builder:build_zip()
	builder:buildMacos()
end

function Package:getStatus(ctx)
	local res = {}
	table.insert(res, { name = "Package (rizu.zip)", value = ctx.fs:getInfo("repo/rizu.zip") and "OK" or "MISSING" })
	table.insert(res, { name = "Package (rizu_macos.zip)", value = ctx.fs:getInfo("repo/rizu_macos.zip") and "OK" or "MISSING" })
	return res
end

return Package
