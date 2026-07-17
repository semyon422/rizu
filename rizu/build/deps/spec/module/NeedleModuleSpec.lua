local BuildConfig = require("rizu.build.BuildConfig")
local ModuleUtil = require("rizu.build.deps.spec.module.ModuleUtil")

---@class rizu.build.deps.spec.module.NeedleModuleSpec
local NeedleModuleSpec = {}

local CFLAGS_BY_TARGET = {
	linux = {"-O2", "-std=c11", "-shared", "-fPIC", "-fvisibility=hidden", "-DNEEDLE_RUNTIME_BUILD"},
	windows = {"-O2", "-std=c11", "-shared", "-DNEEDLE_RUNTIME_BUILD", "-static-libgcc"},
	macos = {"-O2", "-std=c11", "-dynamiclib", "-fPIC", "-fvisibility=hidden", "-DNEEDLE_RUNTIME_BUILD"},
}

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
function NeedleModuleSpec.add(target, spec)
	local artifact_dir = BuildConfig.getArtifactsDir(target)
	local bin_dir = BuildConfig.getBinDir(target)
	local outputs = BuildConfig.getModuleOutputs(target, artifact_dir)
	local names = BuildConfig.getModuleNames(target)
	local artifact = outputs.needle
	local bin_file = bin_dir .. "/" .. names.needle
	local compile_id = ModuleUtil.makeStepIds("needle")
	local source_dir = "aqua/ai/needle/src"
	local sources = {
		source_dir .. "/needle_runtime.c",
		source_dir .. "/needle_tokenizer.c",
		source_dir .. "/needle_kernels.c",
	}
	local inputs = {
		sources[1], sources[2], sources[3],
		source_dir .. "/needle_runtime.h",
		source_dir .. "/needle_tokenizer.h",
		source_dir .. "/needle_kernels.h",
	}

	ModuleUtil.addStep(spec, {
		id = compile_id,
		kind = "source-build",
		status_label = "Needle Runtime Artifact",
		outputs = {artifact},
		inputs = inputs,
		actions = {{
			type = "compile_c",
			compiler = ModuleUtil.CC_BY_TARGET[target],
			env = ModuleUtil.ENV_BY_TARGET[target],
			cflags = CFLAGS_BY_TARGET[target],
			includes = {source_dir},
			sources = sources,
			output = artifact,
			libs = {"m"},
		}},
	})

	ModuleUtil.addPublishStep(spec, "needle", "Needle Runtime", artifact, bin_file)
end

return NeedleModuleSpec
