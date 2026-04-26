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
	require("rizu.build.deps.actions.compile"),
	require("rizu.build.deps.actions.filesystem"),
	require("rizu.build.deps.actions.git"),
	require("rizu.build.deps.actions.platform"),
	require("rizu.build.deps.actions.assertions")
)

local function summarizeAction(action)
	local fields = {"type", "dir", "src_dir", "build_dir", "path", "src", "dst", "url", "archive", "command"}
	local parts = {}
	for _, key in ipairs(fields) do
		local val = action[key]
		if val ~= nil then
			if type(val) == "string" then
				table.insert(parts, key .. "=" .. val)
			else
				table.insert(parts, key .. "=" .. tostring(val))
			end
		end
	end
	return table.concat(parts, ", ")
end

local function hasAllRequired(env, step)
	for _, req in ipairs(step.requires or {}) do
		if not env.ctx.fs:getInfo(Util.resolve(env, req)) then
			return false
		end
	end
	return true
end

local function resolveList(env, list)
	local out = {}
	for _, item in ipairs(list or {}) do
		table.insert(out, Util.resolve(env, item))
	end
	return out
end

local function outputsUpToDate(env, step)
	local outputs = resolveList(env, step.outputs)
	if #outputs == 0 then
		return false
	end

	local oldest_output_modtime
	for _, path in ipairs(outputs) do
		local info = env.ctx.fs:getInfo(path)
		if not info then
			return false
		end
		if info.modtime then
			oldest_output_modtime = oldest_output_modtime and math.min(oldest_output_modtime, info.modtime) or info.modtime
		else
			oldest_output_modtime = nil
		end
	end

	for _, input in ipairs(resolveList(env, step.inputs)) do
		local info = env.ctx.fs:getInfo(input)
		if not info then
			return false
		end
		if oldest_output_modtime and info.modtime and oldest_output_modtime < info.modtime then
			return false
		end
	end

	return true
end

local function shouldSkip(env, step)
	if step.outputs and #step.outputs > 0 then
		return outputsUpToDate(env, step)
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
			error(string.format("Step '%s' action failed (%s): %s", step.id, summarizeAction(action), tostring(result)), 0)
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
