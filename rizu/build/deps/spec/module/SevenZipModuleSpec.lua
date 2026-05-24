local BuildConfig = require("rizu.build.BuildConfig")
local ModuleUtil = require("rizu.build.deps.spec.module.ModuleUtil")

---@class rizu.build.deps.spec.module.SevenZipModuleSpec
local SevenZipModuleSpec = {}

local SEVENZIP_CFLAGS_BY_TARGET = {
	linux = {"-D_GNU_SOURCE", "-shared", "-fPIC"},
	windows = {"-shared", "-fPIC"},
	macos = {"-dynamiclib", "-fPIC"},
}

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
function SevenZipModuleSpec.add(target, spec)
	local artifact_dir = BuildConfig.getArtifactsDir(target)
	local bin_dir = BuildConfig.getBinDir(target)
	local outputs = BuildConfig.getModuleOutputs(target, artifact_dir)
	local names = BuildConfig.getModuleNames(target)

	local artifact = outputs.z7
	local bin_file = bin_dir .. "/" .. names.z7

	local compile_id = ModuleUtil.makeStepIds("z7")
	local compiler = ModuleUtil.CC_BY_TARGET[target]
	local cflags = SEVENZIP_CFLAGS_BY_TARGET[target]
	local env = ModuleUtil.ENV_BY_TARGET[target]

	local sdk_dir = BuildConfig.getSevenZipSdkDir()
	ModuleUtil.addStep(spec, {
		id = compile_id,
		kind = "source-build",
		status_label = "7z Artifact",
		outputs = {artifact},
		inputs = {"aqua/7z.c", sdk_dir .. "/C/Alloc.c", sdk_dir .. "/C/LzmaLib.c"},
		actions = {
			{
				type = "compile_c",
				compiler = compiler,
				env = env,
				cflags = cflags,
				includes = {sdk_dir .. "/C", "aqua"},
				sources = {"aqua/7z.c"},
				output = artifact,
			},
		},
	})

	ModuleUtil.addPublishStep(spec, "z7", "7z", artifact, bin_file)
end

return SevenZipModuleSpec
