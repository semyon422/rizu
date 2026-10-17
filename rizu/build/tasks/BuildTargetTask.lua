local ITask = require("rizu.build.ITask")

local BuildEnv = require("rizu.build.deps.engine.BuildEnv")
local DependencySpec = require("rizu.build.deps.spec.DependencySpec")
local Executor = require("rizu.build.deps.engine.Executor")
local Evaluator = require("rizu.build.deps.engine.Evaluator")

---@class rizu.build.tasks.BuildTargetTask: rizu.build.ITask
---@operator call: rizu.build.tasks.BuildTargetTask
---@field deps string[]
local BuildTargetTask = ITask + {}

---@param target rizu.build.Target
---@return string[]
local function depsForTarget(target)
	---@type string[]
	local deps = {"setup_luajit_linux"}
	if target == "windows" then
		table.insert(deps, "setup_luajit_windows")
	end
	if target == "macos" then
		table.insert(deps, "setup_macos_toolchain")
	end
	return deps
end

---@param target rizu.build.Target
function BuildTargetTask:new(target)
	---@type string
	self.name = "build_target_" .. target
	self.target = target
	self.deps = depsForTarget(target)
end

---@param ctx rizu.build.Context
---@return rizu.build.deps.RunResult[]
function BuildTargetTask:run(ctx)
	if self.target == "macos" then
		local compiler = "build/deps/osxcross/target/bin/x86_64-apple-darwin22.2-clang"
		if not ctx.fs:getInfo(compiler) then
			error("Missing macOS toolchain: " .. compiler .. ". Run './rizu/build/make.lua setup_macos_toolchain' first.", 0)
		end
	end

	local env = BuildEnv.new(ctx, self.target, {initialize_dirs = true})
	local spec = DependencySpec.load(self.target)
	return Executor.runSpec(env, spec)
end

---@param ctx rizu.build.Context
---@return boolean
function BuildTargetTask:upToDate(ctx)
	local env = BuildEnv.new(ctx, self.target, {initialize_dirs = false})
	local spec = DependencySpec.load(self.target)
	return Evaluator.isUpToDate(env, spec)
end

---@param ctx rizu.build.Context
---@return rizu.build.StatusRow[]
function BuildTargetTask:getStatus(ctx)
	local env = BuildEnv.new(ctx, self.target, {initialize_dirs = false})
	local spec = DependencySpec.load(self.target)
	local eval = Evaluator.evaluate(env, spec)
	return Evaluator.renderStatusRows(eval)
end

return BuildTargetTask
