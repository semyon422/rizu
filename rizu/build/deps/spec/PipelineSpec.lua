local BuildConfig = require("rizu.build.BuildConfig")
local Loader = require("rizu.build.deps.spec.Loader")

local PipelineSpec = {}

local function moduleArtifacts(target)
	local out_dir = BuildConfig.getArtifactsDir(target)
	local outputs = BuildConfig.getModuleOutputs(target, out_dir)
	local list = {}
	for _, name in pairs(outputs) do
		table.insert(list, name)
	end
	return list, outputs
end

local function moduleBins(target, outputs)
	local bin_dir = BuildConfig.getBinDir(target)
	local records = BuildConfig.getModuleRecords(target, outputs, bin_dir)
	local list = {}
	for _, record in ipairs(records) do
		table.insert(list, record.bin)
	end
	return list
end

function PipelineSpec.load(target, deps)
	local dep_spec = Loader.load(target, deps)
	local mod_outputs, mod_outputs_map = moduleArtifacts(target)
	local bin_outputs = moduleBins(target, mod_outputs_map)

	local steps = {}
	for _, step in ipairs(dep_spec.steps) do
		table.insert(steps, step)
	end

	table.insert(steps, {
		id = "modules_build",
		kind = "modules",
		status_label = "Modules (" .. target .. ")",
		outputs = mod_outputs,
		requires = dep_spec.outputs,
		actions = {
			{type = "build_modules"},
		},
	})

	table.insert(steps, {
		id = "binaries_sync",
		kind = "sync",
		status_label = "Bin Sync (" .. target .. ")",
		outputs = bin_outputs,
		requires = mod_outputs,
		actions = {
			{type = "sync_binaries"},
		},
	})

	table.insert(steps, {
		id = "package_hooks",
		kind = "package-hooks",
		status_label = "Package Hooks (" .. target .. ")",
		outputs = {},
		requires = bin_outputs,
		actions = {
			{type = "noop"},
		},
	})

	local outputs = {}
	for _, p in ipairs(dep_spec.outputs or {}) do
		table.insert(outputs, p)
	end
	for _, p in ipairs(mod_outputs) do
		table.insert(outputs, p)
	end
	for _, p in ipairs(bin_outputs) do
		table.insert(outputs, p)
	end

	return {
		target = BuildConfig.normalizeTarget(target),
		steps = steps,
		outputs = outputs,
	}
end

return PipelineSpec
