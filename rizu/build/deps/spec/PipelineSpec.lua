local Loader = require("rizu.build.deps.spec.Loader")
local NativeModulesSpec = require("rizu.build.deps.spec.common.NativeModulesSpec")
local PipelineSpec = {}

---@param target rizu.build.Target
---@param deps table
---@return rizu.build.deps.Spec
function PipelineSpec.load(target, deps)
	local dep_spec = Loader.load(target, deps)

	---@type rizu.build.deps.Spec
	local spec = {
		target = target,
		steps = {},
		outputs = {},
	}

	for _, step in ipairs(dep_spec.steps or {}) do
		table.insert(spec.steps, step)
	end
	for _, output in ipairs(dep_spec.outputs or {}) do
		table.insert(spec.outputs, output)
	end

	NativeModulesSpec.add(spec.target, spec)

	return spec
end

return PipelineSpec
