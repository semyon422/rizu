local ITask = require("rizu.build.ITask")
local deps = require("rizu.build.deps.Manifest")

local BuildEnv = require("rizu.build.deps.engine.BuildEnv")
local StepState = require("rizu.build.deps.engine.StepState")
local DependencySpec = require("rizu.build.deps.spec.DependencySpec")

local archive_actions = require("rizu.build.deps.actions.archive")
local git_actions = require("rizu.build.deps.actions.git")

---@class rizu.build.tasks.PrefetchDepsTask: rizu.build.ITask
---@operator call: rizu.build.tasks.PrefetchDepsTask
---@field target rizu.build.Target
---@field deps string[]
local PrefetchDepsTask = ITask + {}

local handlers = {
	download = archive_actions.download,
	git_clone = git_actions.git_clone,
	git_submodule = git_actions.git_submodule,
}

local MACOS_TOOLCHAIN_REPO = "https://github.com/tpoechtrager/osxcross"

---@param target rizu.build.Target
function PrefetchDepsTask:new(target)
	---@type string
	self.name = "prefetch_deps_" .. target
	self.target = target
	self.deps = {}
end

---@param ctx rizu.build.Context
function PrefetchDepsTask:run(ctx)
	local env = BuildEnv.new(ctx, self.target, {initialize_dirs = true})
	local spec = DependencySpec.load(self.target, deps)
	local count = 0

	if self.target == "macos" then
		local ok, err = xpcall(function()
			handlers.git_clone(env, {type = "git_clone", url = MACOS_TOOLCHAIN_REPO, dest = "${deps_dir}/osxcross"})
		end, debug.traceback)
		if not ok then
			error(string.format("Prefetch failed for target '%s', osxcross clone: %s", self.target, tostring(err)), 0)
		end
		count = count + 1
	end

	for _, step in ipairs(spec.steps or {}) do
		if StepState.hasAllRequired(env, step) then
			for _, action in ipairs(step.actions or {}) do
				local handler = handlers[action.type]
				if handler then
					local ok, err = xpcall(function()
						handler(env, action)
					end, debug.traceback)
					if not ok then
						error(string.format("Prefetch failed for target '%s', step '%s': %s", self.target, tostring(step.id), tostring(err)), 0)
					end
					count = count + 1
				end
			end
		end
	end

	print(string.format("Prefetch complete for %s (%d actions)", self.target, count))
end

return PrefetchDepsTask
