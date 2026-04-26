local StepState = require("rizu.build.deps.engine.StepState")

local Evaluator = {}

function Evaluator.evaluateStep(env, step, run_result)
	if not StepState.hasAllRequired(env, step) then
		return {
			id = step.id,
			label = step.status_label or step.id,
			kind = step.kind,
			state = "SKIPPED",
			outputs = StepState.resolveList(env, step.outputs),
		}
	end

	local state, outputs = StepState.outputState(env, step)

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
