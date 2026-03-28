local class = require("class")
local deps = require("build.deps")

local Context = require("build.deps_dsl.engine.Context")
local Executor = require("build.deps_dsl.engine.Executor")
local Guards = require("build.deps_dsl.engine.Guards")
local StatusFormatter = require("build.deps_dsl.engine.StatusFormatter")
local Loader = require("build.deps_dsl.spec.Loader")

---@class build.tasks.FetchDeps
local FetchDeps = class()

function FetchDeps:new(target)
	self.name = "deps_" .. target
	self.target = target
	self.deps = {}
end

function FetchDeps:run(ctx)
	local env = Context.new(ctx, self.target, {initialize_dirs = true})
	local spec = Loader.load(self.target, deps)
	Executor.runSpec(env, spec)
end

function FetchDeps:upToDate(ctx)
	local env = Context.new(ctx, self.target, {initialize_dirs = false})
	local spec = Loader.load(self.target, deps)
	return Guards.isUpToDate(env, spec)
end

function FetchDeps:getStatus(ctx)
	local env = Context.new(ctx, self.target, {initialize_dirs = false})
	local spec = Loader.load(self.target, deps)
	return StatusFormatter.render(env, spec)
end

return FetchDeps
