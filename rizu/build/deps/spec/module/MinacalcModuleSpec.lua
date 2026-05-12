local BuildConfig = require("rizu.build.BuildConfig")
local ModuleUtil = require("rizu.build.deps.spec.module.ModuleUtil")

---@class rizu.build.deps.spec.module.MinacalcModuleSpec
local MinacalcModuleSpec = {}

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
function MinacalcModuleSpec.add(target, spec)
	local artifact_dir = BuildConfig.getArtifactsDir(target)
	local bin_dir = BuildConfig.getBinDir(target)
	local outputs = BuildConfig.getModuleOutputs(target, artifact_dir)
	local names = BuildConfig.getModuleNames(target)

	local artifact = outputs.minacalc
	local bin_file = bin_dir .. "/" .. names.minacalc

	local compile_id = ModuleUtil.makeStepIds("minacalc")
	local compiler = ModuleUtil.CXX_BY_TARGET[target]
	local env = ModuleUtil.ENV_BY_TARGET[target]

	local cflags = {"-DSTANDALONE_CALC", "-std=c++20", "-shared", "-fPIC"}
	if target == "windows" then
		table.insert(cflags, "-static-libstdc++")
		table.insert(cflags, "-static-libgcc")
	elseif target == "macos" then
		table.insert(cflags, "-undefined")
		table.insert(cflags, "dynamic_lookup")
	end

	ModuleUtil.addStep(spec, {
		id = compile_id,
		kind = "source-build",
		status_label = "Minacalc Artifact",
		outputs = {artifact},
		inputs = {"build/deps/minacalc/API.cpp", "build/deps/minacalc/MinaCalc/MinaCalc.cpp"},
		actions = {
			{
				type = "compile_cpp",
				compiler = compiler,
				env = env,
				cflags = cflags,
				sources = {"build/deps/minacalc/MinaCalc/MinaCalc.cpp", "build/deps/minacalc/API.cpp"},
				output = artifact,
				libs = {"m"},
			},
		},
	})

	ModuleUtil.addPublishStep(spec, "minacalc", "Minacalc", artifact, bin_file)
end

return MinacalcModuleSpec
