local BuildConfig = require("rizu.build.BuildConfig")
local Loader = require("rizu.build.deps.spec.Loader")
local NativeModulesSpec = require("rizu.build.deps.spec.common.NativeModulesSpec")
local PipelineSpec = {}

function PipelineSpec.load(target, deps)
	local dep_spec = Loader.load(target, deps)
	local spec = {
		target = BuildConfig.normalizeTarget(target),
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

	table.insert(spec.steps, {
		id = "package_hooks",
		kind = "package-hooks",
		status_label = "Package Hooks (" .. target .. ")",
		outputs = {},
		requires = spec.outputs,
		inputs = {},
		actions = {
			{type = "noop"},
		},
	})

	return spec
end

return PipelineSpec
