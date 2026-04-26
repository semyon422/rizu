local BuildEnv = require("rizu.build.deps.engine.BuildEnv")

local StepState = {}

---@param env rizu.build.deps.Env
---@param value any
---@return any
function StepState.resolve(env, value)
	if type(value) == "table" then
		local out = {}
		for k, v in pairs(value) do
			out[k] = StepState.resolve(env, v)
		end
		return out
	end
	return BuildEnv.interpolate(env, value)
end

---@param env rizu.build.deps.Env
---@param list string[]?
---@return string[]
function StepState.resolveList(env, list)
	local out = {}
	for _, item in ipairs(list or {}) do
		table.insert(out, StepState.resolve(env, item))
	end
	return out
end

---@param env rizu.build.deps.Env
---@param list string[]?
---@return boolean
function StepState.existsAll(env, list)
	for _, path in ipairs(StepState.resolveList(env, list)) do
		if not env.ctx.fs:getInfo(path) then
			return false
		end
	end
	return true
end

---@param env rizu.build.deps.Env
---@param step rizu.build.deps.Step
---@return boolean
function StepState.hasAllRequired(env, step)
	return StepState.existsAll(env, step.requires)
end

---@param env rizu.build.deps.Env
---@param list string[]?
---@return number?
local function oldestModtime(env, list)
	local oldest
	for _, path in ipairs(StepState.resolveList(env, list)) do
		local info = env.ctx.fs:getInfo(path)
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

---@param env rizu.build.deps.Env
---@param step rizu.build.deps.Step
---@return boolean
---@return string[]
function StepState.outputsFresh(env, step)
	local outputs = StepState.resolveList(env, step.outputs)
	if #outputs == 0 then
		return false, outputs
	end

	if not StepState.existsAll(env, step.outputs) then
		return false, outputs
	end

	local inputs = StepState.resolveList(env, step.inputs)
	if #inputs > 0 then
		if not StepState.existsAll(env, step.inputs) then
			return false, outputs
		end
		local oldest_output = oldestModtime(env, step.outputs)
		if oldest_output then
			for _, input in ipairs(inputs) do
				local info = env.ctx.fs:getInfo(input)
				if info and info.modtime and oldest_output < info.modtime then
					return false, outputs
				end
			end
		end
	end

	return true, outputs
end

---@param env rizu.build.deps.Env
---@param step rizu.build.deps.Step
---@return string
---@return string[]
function StepState.outputState(env, step)
	local outputs = StepState.resolveList(env, step.outputs)
	if #outputs == 0 then
		return "OK", outputs
	end
	if not StepState.existsAll(env, step.outputs) then
		return "MISSING", outputs
	end

	local inputs = StepState.resolveList(env, step.inputs)
	if #inputs > 0 then
		if not StepState.existsAll(env, step.inputs) then
			return "MISSING", outputs
		end
		local oldest_output = oldestModtime(env, step.outputs)
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

---@param env rizu.build.deps.Env
---@param step rizu.build.deps.Step
---@return boolean
function StepState.shouldSkip(env, step)
	local fresh = StepState.outputsFresh(env, step)
	return fresh
end

return StepState
