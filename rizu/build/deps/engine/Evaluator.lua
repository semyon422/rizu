local Ctx = require("rizu.build.deps.engine.Context")
local BuildConfig = require("rizu.build.BuildConfig")
local Builder = require("rizu.build.Builder")

local Evaluator = {}

local function interp(env, value)
	return Ctx.interpolate(env, value)
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

local function checkOutputs(env, step)
	local outputs = resolveList(env, step.outputs)
	if #outputs == 0 then
		return "OK", outputs
	end
	if existsAll(env.ctx, outputs) then
		return "OK", outputs
	end
	return "MISSING", outputs
end

local function checkModulesStep(env)
	local target = BuildConfig.normalizeTarget(env.target)
	local builder = Builder(env.ctx, target)
	local records = BuildConfig.getModuleRecords(target, builder:getModuleOutputs(), BuildConfig.getBinDir(target))
	local has_ffmpeg = true
	if target == "macos" then
		has_ffmpeg = builder:getFFmpegPaths() ~= nil
	end
	local saw = false
	for _, mod in ipairs(records) do
		if mod.key ~= "video" or has_ffmpeg then
			saw = true
			local bin_info = env.ctx.fs:getInfo(mod.artifact)
			local src_info = env.ctx.fs:getInfo(mod.source)
			if not bin_info or not src_info then
				return "MISSING"
			end
			if bin_info.modtime and src_info.modtime and bin_info.modtime < src_info.modtime then
				return "OUTDATED"
			end
		end
	end
	if not saw then
		return "SKIPPED"
	end
	return "OK"
end

local function checkSyncStep(env)
	local target = BuildConfig.normalizeTarget(env.target)
	local builder = Builder(env.ctx, target)
	local records = BuildConfig.getModuleRecords(target, builder:getModuleOutputs(), BuildConfig.getBinDir(target))
	for _, item in ipairs(records) do
		if item.artifact and env.ctx.fs:getInfo(item.artifact) and not env.ctx.fs:getInfo(item.bin) then
			return "MISSING"
		end
	end
	return "OK"
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
	if step.kind == "modules" then
		state = checkModulesStep(env)
	elseif step.kind == "sync" then
		state = checkSyncStep(env)
	else
		state, outputs = checkOutputs(env, step)
	end

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
	table.insert(rows, {name = "Pipeline (" .. tostring(eval.target) .. ")", value = eval.aggregate})
	return rows
end

function Evaluator.isUpToDate(env, spec)
	local eval = Evaluator.evaluate(env, spec)
	return eval.aggregate == "OK"
end

return Evaluator
