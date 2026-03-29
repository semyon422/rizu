local Util = require("rizu.build.deps.actions._util")

---@class rizu.build.deps.engine.Executor
local Executor = {}

local function mergeHandlers(...)
	local out = {}
	for i = 1, select("#", ...) do
		local src = select(i, ...)
		for k, v in pairs(src) do
			out[k] = v
		end
	end
	return out
end

local handlers = mergeHandlers(
	require("rizu.build.deps.actions.archive"),
	require("rizu.build.deps.actions.shell"),
	require("rizu.build.deps.actions.filesystem"),
	require("rizu.build.deps.actions.git"),
	require("rizu.build.deps.actions.platform"),
	require("rizu.build.deps.actions.assertions"),
	require("rizu.build.deps.actions.build")
)

local function hasAllRequired(env, step)
	for _, req in ipairs(step.requires or {}) do
		if not env.ctx.fs:getInfo(Util.resolve(env, req)) then
			return false
		end
	end
	return true
end

local function shouldSkip(env, step)
	if step.kind == "modules" then
		return false
	end
	if step.outputs and #step.outputs > 0 then
		for _, p in ipairs(step.outputs) do
			if not env.ctx.fs:getInfo(Util.resolve(env, p)) then
				return false
			end
		end
		return true
	end
	local checks = step.skip_if_exists_all
	if checks and #checks > 0 then
		for _, p in ipairs(checks) do
			if not env.ctx.fs:getInfo(Util.resolve(env, p)) then
				return false
			end
		end
		return true
	end
	return false
end

---@param env rizu.build.deps.Env
---@param step rizu.build.deps.Step
---@return rizu.build.deps.RunResult
function Executor.runStep(env, step)
	if shouldSkip(env, step) then
		return {ok = true, exit_code = 0, step_id = step.id, command = "<skipped>", stderr_hint = nil}
	end

	local last = {ok = true, exit_code = 0, step_id = step.id, command = "<noop>", stderr_hint = nil}
	for _, action in ipairs(step.actions or {}) do
		local handler = handlers[action.type]
		if not handler then
			error("Unknown action type: " .. tostring(action.type))
		end
		local ok, result = xpcall(function()
			return handler(env, action)
		end, debug.traceback)
		if not ok then
			error(string.format("Step '%s' failed: %s", step.id, tostring(result)), 0)
		end
		if result then
			result.step_id = step.id
			last = result
		end
	end
	return last
end

---@param env rizu.build.deps.Env
---@param spec rizu.build.deps.Spec
---@return rizu.build.deps.RunResult[]
function Executor.runSpec(env, spec)
	local results = {}
	for _, step in ipairs(spec.steps or {}) do
		if hasAllRequired(env, step) then
			table.insert(results, Executor.runStep(env, step))
		else
			table.insert(results, {
				ok = true,
				exit_code = 0,
				step_id = step.id,
				command = "<skipped: requires missing>",
				stderr_hint = nil,
			})
		end
	end
	return results
end

return Executor
