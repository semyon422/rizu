local BuildConfig = require("rizu.build.BuildConfig")
local ModuleUtil = require("rizu.build.deps.spec.module.ModuleUtil")

---@class rizu.build.deps.spec.module.ModuleDirsSpec
local ModuleDirsSpec = {}

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
function ModuleDirsSpec.add(target, spec)
	local artifact_dir = BuildConfig.getArtifactsDir(target)
	local bin_dir = BuildConfig.getBinDir(target)

	ModuleUtil.addStep(spec, {
		id = "native_module_dirs",
		kind = "source-build",
		status_label = "Native Module Dirs",
		outputs = {artifact_dir, bin_dir},
		inputs = {},
		actions = {
			{type = "ensure_dir", path = "build/artifacts"},
			{type = "ensure_dir", path = artifact_dir},
			{type = "ensure_dir", path = "bin"},
			{type = "ensure_dir", path = bin_dir},
		},
	})
end

return ModuleDirsSpec
