local class = require("class")
local deps = require("build.deps")

local Env = require("build.tasks.fetchdeps.env")
local Common = require("build.tasks.fetchdeps.common")
local Linux = require("build.tasks.fetchdeps.linux")
local Windows = require("build.tasks.fetchdeps.windows")
local Macos = require("build.tasks.fetchdeps.macos")
local Status = require("build.tasks.fetchdeps.status")

---@class build.tasks.FetchDeps
local FetchDeps = class()

function FetchDeps:new(target)
	self.name = "deps_" .. target
	self.target = target
	self.deps = {}
end

function FetchDeps:run(ctx)
	local env = Env.new(ctx, self.target, deps)
	Common.processFFmpeg(env)
	Common.processGenericZipDeps(env)
	Common.processGitDeps(env)
	Common.processPrebuiltBins(env)
	Linux.run(env)
	Windows.run(env)
	Macos.run(env)
	Common.processSevenZip(env)
	Common.processLoveArtifacts(env)
end

function FetchDeps:upToDate(ctx)
	local env = Env.new(ctx, self.target, deps, {initialize_dirs = false})
	return Status.upToDate(env)
end

function FetchDeps:getStatus(ctx)
	local env = Env.new(ctx, self.target, deps, {initialize_dirs = false})
	return Status.getStatus(env)
end

return FetchDeps
