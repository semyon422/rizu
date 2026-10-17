local StepState = require("rizu.build.deps.engine.StepState")

---@class rizu.build.deps.engine.Executor
local Executor = {}

---@param ... rizu.build.deps.Actions
---@return rizu.build.deps.Actions
local function mergeHandlers(...)
	---@type rizu.build.deps.Actions
	local out = {}
	for i = 1, select("#", ...) do
		---@type rizu.build.deps.Actions
		local src = select(i, ...)
		for action_type, handler in pairs(src) do
			out[action_type] = handler
		end
	end
	return out
end

---@type rizu.build.deps.Actions
local handlers = mergeHandlers(
	require("rizu.build.deps.actions.archive"),
	require("rizu.build.deps.actions.shell"),
	require("rizu.build.deps.actions.compile"),
	require("rizu.build.deps.actions.filesystem"),
	require("rizu.build.deps.actions.git"),
	require("rizu.build.deps.actions.assertions")
)

---@param action rizu.build.deps.Action
---@return string
local function summarizeAction(action)
	local fields = {"type", "dir", "src_dir", "build_dir", "path", "src", "dst", "url", "archive", "command"}
	---@type string[]
	local parts = {}
	for _, key in ipairs(fields) do
		-- Summary keys intentionally index the heterogeneous action shape dynamically.
		---@diagnostic disable-next-line: no-unknown
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

---@param env rizu.build.deps.Env
---@param step rizu.build.deps.Step
---@return rizu.build.deps.RunResult
function Executor.runStep(env, step)
	if StepState.shouldSkip(env, step) then
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
		table.insert(results, Executor.runStep(env, step))
	end
	return results
end

return Executor
