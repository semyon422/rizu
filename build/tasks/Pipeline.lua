local class = require("class")
local deps = require("build.deps")

local Context = require("build.deps_dsl.engine.Context")
local Executor = require("build.deps_dsl.engine.Executor")
local Evaluator = require("build.deps_dsl.engine.Evaluator")
local PipelineSpec = require("build.deps_dsl.spec.Pipeline")

---@class build.tasks.Pipeline
local Pipeline = class()

function Pipeline:new(target)
	self.name = "pipeline_" .. target
	self.target = target
	self.deps = {}
end

function Pipeline:run(ctx)
	local env = Context.new(ctx, self.target, {initialize_dirs = true})
	local spec = PipelineSpec.load(self.target, deps)
	return Executor.runSpec(env, spec)
end

function Pipeline:upToDate(ctx)
	local env = Context.new(ctx, self.target, {initialize_dirs = false})
	local spec = PipelineSpec.load(self.target, deps)
	return Evaluator.isUpToDate(env, spec)
end

function Pipeline:getStatus(ctx)
	local env = Context.new(ctx, self.target, {initialize_dirs = false})
	local spec = PipelineSpec.load(self.target, deps)
	local eval = Evaluator.evaluate(env, spec)
	return Evaluator.renderStatusRows(eval)
end

return Pipeline
