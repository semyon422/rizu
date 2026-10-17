local BuildConfig = require("rizu.build.BuildConfig")
local ModuleUtil = require("rizu.build.deps.spec.module.ModuleUtil")

---@class rizu.build.deps.spec.module.LuamidiModuleSpec
local LuamidiModuleSpec = {}

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
function LuamidiModuleSpec.add(target, spec)
	local artifact_dir = BuildConfig.getArtifactsDir(target)
	local bin_dir = BuildConfig.getBinDir(target)
	local outputs = BuildConfig.getModuleOutputs(target, artifact_dir)
	local names = BuildConfig.getModuleNames(target)

	local artifact = outputs.luamidi
	local bin_file = bin_dir .. "/" .. names.luamidi

	local compile_id = ModuleUtil.makeStepIds("luamidi")
	local compiler = ModuleUtil.CXX_BY_TARGET[target]
	local env = ModuleUtil.ENV_BY_TARGET[target]

	local cflags = {"-shared", "-fPIC", "-std=c++17", "-DluaL_reg=luaL_Reg"}
	local libs = {}
	local lib_dirs = {}
	local ldflags = {}
	if target == "windows" then
		table.insert(cflags, "-DWIN32")
		table.insert(cflags, "-D__WINDOWS_MM__")
		table.insert(cflags, "-static-libstdc++")
		table.insert(cflags, "-static-libgcc")
		lib_dirs = {"tree/lib"}
		libs = {"winmm", ":libluajit-5.1.dll.a"}
	elseif target == "macos" then
		table.insert(cflags, "-D__MACOSX_CORE__")
		table.insert(cflags, "-undefined")
		table.insert(cflags, "dynamic_lookup")
		ldflags = {"-framework", "CoreMIDI", "-framework", "CoreFoundation", "-framework", "CoreAudio", "-framework", "CoreServices"}
	else
		table.insert(cflags, "-D__LINUX_ALSA__")
		libs = {"asound", "pthread"}
	end

	local deps_dir = BuildConfig.getLuamidiDepsDir()
	ModuleUtil.addStep(spec, {
		id = compile_id,
		kind = "source-build",
		status_label = "Luamidi Artifact",
		outputs = {artifact},
		inputs = {
			deps_dir .. "/src/luamidi.cpp",
			deps_dir .. "/rtmidi/RtMidi.cpp",
			deps_dir .. "/rtmidi/RtMidi.h",
			"tree/include/luajit-2.1/lua.h",
		},
		actions = {
			{
				type = "compile_cpp",
				compiler = compiler,
				env = env,
				cflags = cflags,
				includes = {"tree/include/luajit-2.1", deps_dir .. "/rtmidi"},
				sources = {deps_dir .. "/src/luamidi.cpp", deps_dir .. "/rtmidi/RtMidi.cpp"},
				output = artifact,
				lib_dirs = lib_dirs,
				libs = libs,
				ldflags = ldflags,
			},
		},
	})

	ModuleUtil.addPublishStep(spec, "luamidi", "Luamidi", artifact, bin_file)
end

return LuamidiModuleSpec
