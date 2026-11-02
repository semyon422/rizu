local ITask = require("rizu.build.ITask")
local BuildEnv = require("rizu.build.deps.engine.BuildEnv")
local Executor = require("rizu.build.deps.engine.Executor")
local LoveArtifactsSpec = require("rizu.build.deps.spec.common.LoveArtifactsSpec")

---@class rizu.build.tasks.UpdateLoveTask : rizu.build.ITask
---@operator call: rizu.build.tasks.UpdateLoveTask
---@field target rizu.build.Target
local UpdateLoveTask = ITask + {}

local step_ids = {linux = "love_linux", windows = "love_win", macos = "love_macos"}

---@param target rizu.build.Target
function UpdateLoveTask:new(target)
	assert(step_ids[target], "Unsupported LÖVE target: " .. tostring(target))
	---@type string
	self.name = "update_love_" .. target
	self.target = target
	self.deps = {}
end

---@param ctx rizu.build.Context
function UpdateLoveTask:run(ctx)
	local env = BuildEnv.new(ctx, self.target)
	---@type rizu.build.deps.Spec
	local spec = {steps = {}}
	LoveArtifactsSpec.add(spec)
	for _, step in ipairs(spec.steps) do
		if step.id == step_ids[self.target] then
			for _, action in ipairs(step.actions) do
				if action.type == "download" then
					assert(ctx.downloader:download(BuildEnv.interpolate(env, action.url), BuildEnv.interpolate(env, action.dest)), "LÖVE download failed")
				end
			end
			-- Explicit refresh must also reinstall an already-present runtime.
			step.outputs = {}
			Executor.runStep(env, step)
			print("LÖVE updated for " .. self.target)
			return
		end
	end
	error("Missing LÖVE artifact spec for " .. self.target)
end

return UpdateLoveTask
