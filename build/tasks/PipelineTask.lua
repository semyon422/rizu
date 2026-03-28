local ITask = require("build.ITask")
local deps = require("build.deps")

local Context = require("build.deps_dsl.engine.Context")
local Executor = require("build.deps_dsl.engine.Executor")
local Evaluator = require("build.deps_dsl.engine.Evaluator")
local PipelineSpec = require("build.deps_dsl.spec.PipelineSpec")

---@class build.tasks.PipelineTask: build.ITask
---@operator call: build.tasks.PipelineTask
---@field deps string[]
local PipelineTask = ITask + {}

---@param target build.Target
function PipelineTask:new(target)
	self.name = "pipeline_" .. target
	self.target = target
	self.deps = {}
end

---@param ctx build.Context
---@return build.deps_dsl.RunResult[]
function PipelineTask:run(ctx)
	local env = Context.new(ctx, self.target, {initialize_dirs = true})
	local spec = PipelineSpec.load(self.target, deps)
	return Executor.runSpec(env, spec)
end

---@param ctx build.Context
---@return boolean
function PipelineTask:upToDate(ctx)
	local env = Context.new(ctx, self.target, {initialize_dirs = false})
	local spec = PipelineSpec.load(self.target, deps)
	return Evaluator.isUpToDate(env, spec)
end

---@param ctx build.Context
---@return build.StatusRow[]
function PipelineTask:getStatus(ctx)
	local env = Context.new(ctx, self.target, {initialize_dirs = false})
	local spec = PipelineSpec.load(self.target, deps)
	local eval = Evaluator.evaluate(env, spec)
	return Evaluator.renderStatusRows(eval)
end

return PipelineTask
