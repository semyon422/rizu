---@class rizu.build.deps.spec.module.ModuleUtil
local ModuleUtil = {}

ModuleUtil.MACOS_CC = "${root_abs}/build/deps/osxcross/target/bin/x86_64-apple-darwin22.2-clang"
ModuleUtil.MACOS_CXX = "${root_abs}/build/deps/osxcross/target/bin/x86_64-apple-darwin22.2-clang++"
ModuleUtil.MACOS_TC_BIN = "${root_abs}/build/deps/osxcross/target/bin"
ModuleUtil.MACOS_ENV = {PATH = ModuleUtil.MACOS_TC_BIN .. ":$PATH"}

ModuleUtil.CC_BY_TARGET = {
	linux = "gcc",
	windows = "x86_64-w64-mingw32-gcc",
	macos = ModuleUtil.MACOS_CC,
}
ModuleUtil.CXX_BY_TARGET = {
	linux = "g++",
	windows = "x86_64-w64-mingw32-g++",
	macos = ModuleUtil.MACOS_CXX,
}
ModuleUtil.ENV_BY_TARGET = {
	macos = ModuleUtil.MACOS_ENV,
}

---@param spec rizu.build.deps.Spec
---@param step rizu.build.deps.Step
function ModuleUtil.addStep(spec, step)
	table.insert(spec.steps, step)
end

---@param key string
---@return string artifact_id
---@return string publish_id
function ModuleUtil.makeStepIds(key)
	return "module_" .. key .. "_artifact", "module_" .. key .. "_bin"
end

---@param spec rizu.build.deps.Spec
---@param key string
---@param label string
---@param artifact string
---@param bin_file string
---@param inputs string[]?
function ModuleUtil.addPublishStep(spec, key, label, artifact, bin_file, inputs)
	local _, publish_id = ModuleUtil.makeStepIds(key)
	ModuleUtil.addStep(spec, {
		id = publish_id,
		kind = "source-build",
		status_label = label .. " Bin",
		outputs = {bin_file},
		inputs = inputs or {artifact},
		actions = {
			{type = "copy_exact", src = artifact, dst = bin_file, flags = "-f"},
		},
	})
end

return ModuleUtil
