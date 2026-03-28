local ITask = require("rizu.build.ITask")
local deps = require("rizu.build.deps.Manifest")

local Context = require("rizu.build.deps.engine.Context")
local Executor = require("rizu.build.deps.engine.Executor")
local Evaluator = require("rizu.build.deps.engine.Evaluator")
local PipelineSpec = require("rizu.build.deps.spec.PipelineSpec")

---@class rizu.build.tasks.PipelineTask: rizu.build.ITask
---@operator call: rizu.build.tasks.PipelineTask
---@field deps string[]
local PipelineTask = ITask + {}

---@param target rizu.build.Target
function PipelineTask:new(target)
	self.name = "pipeline_" .. target
	self.target = target
	self.deps = {}
end

---@param ctx rizu.build.Context
---@return rizu.build.deps.RunResult[]
function PipelineTask:run(ctx)
	local env = Context.new(ctx, self.target, {initialize_dirs = true})
	local spec = PipelineSpec.load(self.target, deps)
	return Executor.runSpec(env, spec)
end

---@param ctx rizu.build.Context
---@return boolean
function PipelineTask:upToDate(ctx)
	local env = Context.new(ctx, self.target, {initialize_dirs = false})
	local spec = PipelineSpec.load(self.target, deps)
	return Evaluator.isUpToDate(env, spec)
end

---@param ctx rizu.build.Context
---@return rizu.build.StatusRow[]
function PipelineTask:getStatus(ctx)
	local env = Context.new(ctx, self.target, {initialize_dirs = false})
	local spec = PipelineSpec.load(self.target, deps)
	local eval = Evaluator.evaluate(env, spec)
	return Evaluator.renderStatusRows(eval)
end

return PipelineTask
