local BuildEnv = require("rizu.build.deps.engine.BuildEnv")

local Evaluator = {}

local function interp(env, value)
	return BuildEnv.interpolate(env, value)
end

local function resolveList(env, list)
	local out = {}
	for _, v in ipairs(list or {}) do
		table.insert(out, interp(env, v))
	end
	return out
end

local function existsAll(ctx, list)
	for _, p in ipairs(list or {}) do
		if not ctx.fs:getInfo(p) then
			return false
		end
	end
	return true
end

local function oldestModtime(ctx, list)
	local oldest
	for _, path in ipairs(list or {}) do
		local info = ctx.fs:getInfo(path)
		if not info then
			return nil
		end
		if info.modtime then
			oldest = oldest and math.min(oldest, info.modtime) or info.modtime
		else
			return nil
		end
	end
	return oldest
end

local function checkOutputs(env, step)
	local outputs = resolveList(env, step.outputs)
	if #outputs == 0 then
		return "OK", outputs
	end
	if not existsAll(env.ctx, outputs) then
		return "MISSING", outputs
	end

	local inputs = resolveList(env, step.inputs)
	if #inputs > 0 then
		if not existsAll(env.ctx, inputs) then
			return "MISSING", outputs
		end
		local oldest_output = oldestModtime(env.ctx, outputs)
		if oldest_output then
			for _, input in ipairs(inputs) do
				local info = env.ctx.fs:getInfo(input)
				if info and info.modtime and oldest_output < info.modtime then
					return "OUTDATED", outputs
				end
			end
		end
	end

	return "OK", outputs
end

function Evaluator.evaluateStep(env, step, run_result)
	local requires = resolveList(env, step.requires)
	if #requires > 0 and not existsAll(env.ctx, requires) then
		return {
			id = step.id,
			label = step.status_label or step.id,
			kind = step.kind,
			state = "SKIPPED",
			outputs = resolveList(env, step.outputs),
		}
	end

	local state
	local outputs = resolveList(env, step.outputs)
	state, outputs = checkOutputs(env, step)

	if run_result and run_result.ok == false then
		state = "FAILED"
	end

	return {
		id = step.id,
		label = step.status_label or step.id,
		kind = step.kind,
		state = state,
		outputs = outputs,
		result = run_result,
	}
end

function Evaluator.evaluate(env, spec, run_results)
	local results_by_id = {}
	for _, rr in ipairs(run_results or {}) do
		results_by_id[rr.step_id] = rr
	end

	local steps = {}
	local aggregate = "OK"
	for _, step in ipairs(spec.steps or {}) do
		local st = Evaluator.evaluateStep(env, step, results_by_id[step.id])
		table.insert(steps, st)
		if st.state == "FAILED" then
			aggregate = "FAILED"
		elseif st.state == "OUTDATED" and aggregate ~= "FAILED" then
			aggregate = "OUTDATED"
		elseif st.state == "MISSING" and aggregate ~= "FAILED" and aggregate ~= "OUTDATED" then
			aggregate = "MISSING"
		end
	end

	return {
		target = spec.target,
		steps = steps,
		aggregate = aggregate,
	}
end

function Evaluator.renderStatusRows(eval)
	local rows = {}
	for _, step in ipairs(eval.steps or {}) do
		table.insert(rows, {name = step.label, value = step.state})
	end
	table.insert(rows, {name = "Build Target (" .. tostring(eval.target) .. ")", value = eval.aggregate})
	return rows
end

function Evaluator.isUpToDate(env, spec)
	local eval = Evaluator.evaluate(env, spec)
	return eval.aggregate == "OK"
end

return Evaluator
