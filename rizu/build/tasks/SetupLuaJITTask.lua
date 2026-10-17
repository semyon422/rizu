local ITask = require("rizu.build.ITask")

local BuildEnv = require("rizu.build.deps.engine.BuildEnv")
local Evaluator = require("rizu.build.deps.engine.Evaluator")
local Executor = require("rizu.build.deps.engine.Executor")
local LuaJITSpec = require("rizu.build.deps.spec.common.LuaJITSpec")

---@class rizu.build.tasks.SetupLuaJITTask: rizu.build.ITask
---@operator call: rizu.build.tasks.SetupLuaJITTask
---@field target rizu.build.LuaJITTarget
---@field deps string[]
local SetupLuaJITTask = ITask + {}

---@param target rizu.build.LuaJITTarget
function SetupLuaJITTask:new(target)
	self.target = target
	---@type string
	self.name = "setup_luajit_" .. target
	self.deps = target == "windows" and {"setup_luajit_linux"} or {}
end

---@param ctx rizu.build.Context
---@return rizu.build.deps.Env
function SetupLuaJITTask:buildEnv(ctx)
	return BuildEnv.new(ctx, self.target, {initialize_dirs = true})
end

---@param ctx rizu.build.Context
function SetupLuaJITTask:run(ctx)
	local env = self:buildEnv(ctx)
	Executor.runSpec(env, LuaJITSpec.load(self.target))
end

---@param ctx rizu.build.Context
---@return boolean
function SetupLuaJITTask:upToDate(ctx)
	local env = BuildEnv.new(ctx, self.target, {initialize_dirs = false})
	return Evaluator.isUpToDate(env, LuaJITSpec.load(self.target))
end

---@param ctx rizu.build.Context
---@return rizu.build.StatusRow[]
function SetupLuaJITTask:getStatus(ctx)
	local env = BuildEnv.new(ctx, self.target, {initialize_dirs = false})
	local eval = Evaluator.evaluate(env, LuaJITSpec.load(self.target))
	---@type rizu.build.StatusRow[]
	local rows = {}
	for _, step in ipairs(eval.steps) do
		table.insert(rows, {name = step.label, value = step.state})
	end
	return rows
end

return SetupLuaJITTask
