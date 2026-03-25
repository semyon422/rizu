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

return Package
