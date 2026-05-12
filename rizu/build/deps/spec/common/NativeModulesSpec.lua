local BuildConfig = require("rizu.build.BuildConfig")

---@class rizu.build.deps.spec.common.NativeModulesSpec
local NativeModulesSpec = {}

local MACOS_CC = "${root_abs}/build/deps/osxcross/target/bin/x86_64-apple-darwin22.2-clang"
local MACOS_CXX = "${root_abs}/build/deps/osxcross/target/bin/x86_64-apple-darwin22.2-clang++"
local MACOS_TC_BIN = "${root_abs}/build/deps/osxcross/target/bin"
local MACOS_ENV = {PATH = MACOS_TC_BIN .. ":$PATH"}
local CC_BY_TARGET = {
	linux = "gcc",
	windows = "x86_64-w64-mingw32-gcc",
	macos = MACOS_CC,
}
local CXX_BY_TARGET = {
	linux = "g++",
	windows = "x86_64-w64-mingw32-g++",
	macos = MACOS_CXX,
}
local ENV_BY_TARGET = {
	macos = MACOS_ENV,
}
local SEVENZIP_CFLAGS_BY_TARGET = {
	linux = {"-D_GNU_SOURCE", "-shared", "-fPIC"},
	windows = {"-shared", "-fPIC"},
	macos = {"-dynamiclib", "-fPIC"},
}
local FFMPEG_INCLUDE_BY_TARGET = {
	linux = "build/deps/ffmpeg-linux/include",
	windows = "build/deps/ffmpeg-win/include",
	macos = "build/deps/local/macos/ffmpeg/include",
}
local SEVENZIP_SDK_INPUTS = {
	"build/deps/7zsdk/C/Alloc.c",
	"build/deps/7zsdk/C/LzmaLib.c",
}

---@param spec rizu.build.deps.Spec
---@param outputs string[]?
local function appendOutputs(spec, outputs)
	for _, path in ipairs(outputs or {}) do
		table.insert(spec.outputs, path)
	end
end

---@param spec rizu.build.deps.Spec
---@param step rizu.build.deps.Step
local function addStep(spec, step)
	table.insert(spec.steps, step)
	appendOutputs(spec, step.outputs)
end

local function makeStepIds(key)
	return "module_" .. key .. "_artifact", "module_" .. key .. "_bin"
end

---@param spec rizu.build.deps.Spec
---@param key string
---@param label string
---@param artifact string
---@param bin_file string
---@param inputs string[]?
local function addPublishStep(spec, key, label, artifact, bin_file, inputs)
	local _, publish_id = makeStepIds(key)
	addStep(spec, {
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

---@param spec rizu.build.deps.Spec
---@param target rizu.build.Target
---@param artifact string
---@param bin_file string
local function add7z(spec, target, artifact, bin_file)
	local compile_id = makeStepIds("z7")
	local compiler = CC_BY_TARGET[target]
	local cflags = SEVENZIP_CFLAGS_BY_TARGET[target]
	local env = ENV_BY_TARGET[target]

	addStep(spec, {
		id = compile_id,
		kind = "source-build",
		status_label = "7z Artifact",
		outputs = {artifact},
		inputs = {"aqua/7z.c", SEVENZIP_SDK_INPUTS[1], SEVENZIP_SDK_INPUTS[2]},
		actions = {
			{
				type = "compile_c",
				compiler = compiler,
				env = env,
				cflags = cflags,
				includes = {"build/deps/7zsdk/C", "aqua"},
				sources = {"aqua/7z.c"},
				output = artifact,
			},
		},
	})

	addPublishStep(spec, "z7", "7z", artifact, bin_file)
end

---@param target rizu.build.Target
---@param artifact string
---@return rizu.build.deps.Action
local function videoCompileAction(target, artifact)
	local compiler = "gcc"
	local cflags = {"-shared", "-fPIC", "-Wl,-rpath,'$ORIGIN'"}
	local lib_dirs = {"build/deps/ffmpeg-linux/lib"}
	local env
	if target == "windows" then
		compiler = CC_BY_TARGET.windows
		cflags = {"-shared", "-fPIC"}
		lib_dirs = {"tree/lib", "build/deps/ffmpeg-win/lib"}
	elseif target == "macos" then
		compiler = CC_BY_TARGET.macos
		env = ENV_BY_TARGET.macos
		cflags = {"-shared", "-fPIC", "-undefined", "dynamic_lookup", "-Wl,-rpath,@loader_path"}
		lib_dirs = {"build/deps/local/macos/ffmpeg/lib"}
	end

	local libs = {"avformat", "avcodec", "swresample", "swscale", "avutil", "m"}
	if target == "windows" then
		table.insert(libs, ":libluajit-5.1.dll.a")
	end

	return {
		type = "compile_c",
		compiler = compiler,
		env = env,
		cflags = cflags,
		includes = {
			"tree/include/luajit-2.1",
			FFMPEG_INCLUDE_BY_TARGET[target],
		},
		sources = {"aqua/video.c"},
		output = artifact,
		lib_dirs = lib_dirs,
		libs = libs,
	}
end

---@param target rizu.build.Target
---@return string[]
local function videoRequires(target)
	if target == "windows" then
		return {
			"tree/include/luajit-2.1/lua.h",
			"tree/lib/libluajit-5.1.dll.a",
			"build/deps/ffmpeg-win/include/libavcodec/avcodec.h",
			"build/deps/ffmpeg-win/lib/libavcodec.dll.a",
		}
	elseif target == "macos" then
		return {
			"tree/include/luajit-2.1/lua.h",
			"build/deps/local/macos/ffmpeg/include/libavcodec/avcodec.h",
			"build/deps/local/macos/ffmpeg/lib/libavcodec.dylib",
		}
	end
	return {
		"tree/include/luajit-2.1/lua.h",
		"build/deps/ffmpeg-linux/include/libavcodec/avcodec.h",
		"build/deps/ffmpeg-linux/lib/libavcodec.so.62",
	}
end

---@param spec rizu.build.deps.Spec
---@param target rizu.build.Target
---@param artifact string
---@param bin_file string
local function addVideo(spec, target, artifact, bin_file)
	local compile_id = makeStepIds("video")
	local required_inputs = videoRequires(target)
	local inputs = {"aqua/video.c"}
	for _, req in ipairs(required_inputs) do
		table.insert(inputs, req)
	end

	addStep(spec, {
		id = compile_id,
		kind = "source-build",
		status_label = "Video Artifact",
		outputs = {artifact},
		inputs = inputs,
		actions = {videoCompileAction(target, artifact)},
	})

	addPublishStep(spec, "video", "Video", artifact, bin_file)
end

---@param target rizu.build.Target
---@return string, {[string]: string}?
local function minacalcCompiler(target)
	return CXX_BY_TARGET[target], ENV_BY_TARGET[target]
end

---@param spec rizu.build.deps.Spec
---@param target rizu.build.Target
---@param artifact string
---@param bin_file string
local function addMinacalc(spec, target, artifact, bin_file)
	local compile_id = makeStepIds("minacalc")
	local compiler, env = minacalcCompiler(target)
	local cflags = {"-DSTANDALONE_CALC", "-std=c++20", "-shared", "-fPIC"}
	if target == "windows" then
		table.insert(cflags, "-static-libstdc++")
		table.insert(cflags, "-static-libgcc")
	elseif target == "macos" then
		table.insert(cflags, "-undefined")
		table.insert(cflags, "dynamic_lookup")
	end

	addStep(spec, {
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

	addPublishStep(spec, "minacalc", "Minacalc", artifact, bin_file)
end

---@param spec rizu.build.deps.Spec
---@param target rizu.build.Target
---@param artifact string
---@param bin_file string
local function addLuamidi(spec, target, artifact, bin_file)
	local compile_id = makeStepIds("luamidi")
	local compiler, env = minacalcCompiler(target)
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

	addStep(spec, {
		id = compile_id,
		kind = "source-build",
		status_label = "Luamidi Artifact",
		outputs = {artifact},
		inputs = {
			"build/deps/luamidi/src/luamidi.cpp",
			"build/deps/luamidi/rtmidi/RtMidi.cpp",
			"build/deps/luamidi/rtmidi/RtMidi.h",
			"tree/include/luajit-2.1/lua.h",
		},
		actions = {
			{
				type = "compile_cpp",
				compiler = compiler,
				env = env,
				cflags = cflags,
				includes = {"tree/include/luajit-2.1", "build/deps/luamidi/rtmidi"},
				sources = {"build/deps/luamidi/src/luamidi.cpp", "build/deps/luamidi/rtmidi/RtMidi.cpp"},
				output = artifact,
				lib_dirs = lib_dirs,
				libs = libs,
				ldflags = ldflags,
			},
		},
	})

	addPublishStep(spec, "luamidi", "Luamidi", artifact, bin_file)
end

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
function NativeModulesSpec.add(target, spec)
	local artifact_dir = BuildConfig.getArtifactsDir(target)
	local bin_dir = BuildConfig.getBinDir(target)
	local outputs = BuildConfig.getModuleOutputs(target, artifact_dir)
	local names = BuildConfig.getModuleNames(target)

	addStep(spec, {
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

	add7z(spec, target, outputs.z7, bin_dir .. "/" .. names.z7)
	addVideo(spec, target, outputs.video, bin_dir .. "/" .. names.video)
	addMinacalc(spec, target, outputs.minacalc, bin_dir .. "/" .. names.minacalc)
	addLuamidi(spec, target, outputs.luamidi, bin_dir .. "/" .. names.luamidi)
end

return NativeModulesSpec
