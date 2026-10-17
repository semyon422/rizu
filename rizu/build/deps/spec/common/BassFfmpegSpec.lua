local BuildConfig = require("rizu.build.BuildConfig")
local MacOSCross = require("rizu.build.deps.spec.source.MacOSCross")
local ModuleUtil = require("rizu.build.deps.spec.module.ModuleUtil")

---@class rizu.build.deps.spec.common.BassFfmpegSpec
local BassFfmpegSpec = {}

local OUTPUT_NAME = {
	linux = "libbass_ffmpeg.so",
	windows = "bass_ffmpeg.dll",
	macos = "libbass_ffmpeg.dylib",
}
local BASS_OUTPUT_NAME = {
	linux = "libbass.so",
	windows = "bass.dll",
	macos = "libbass.dylib",
}

---@param target rizu.build.Target
---@return string?
local function ffmpegLibInput(target)
	if target == "windows" then
		return BuildConfig.getFfmpegDepsDir(target) .. "/lib/libavcodec.dll.a"
	end
	if target == "macos" then
		return BuildConfig.getFfmpegDepsDir(target) .. "/lib/libavcodec.dylib"
	end
	return BuildConfig.getFfmpegDepsDir(target) .. "/lib/libavcodec.so.62"
end

---@param target rizu.build.Target
---@return rizu.build.deps.Action
local function compileAction(target)
	local out_name = OUTPUT_NAME[target]
	local compiler = ModuleUtil.CC_BY_TARGET[target]
	local env = ModuleUtil.ENV_BY_TARGET[target]
	local cflags = {"-shared", "-fPIC", "-O2", "-Wl,-rpath,'$ORIGIN'"}
	local lib_dirs = {BuildConfig.getFfmpegDepsDir(target) .. "/lib", BuildConfig.getBinDir(target)}
	local libs = {"avformat", "avcodec", "swresample", "avutil", "bass"}
	local ldflags = {}

	if target == "windows" then
		cflags = {"-shared", "-O2"}
	elseif target == "macos" then
		cflags = {"-shared", "-fPIC", "-O2", "-Wl,-rpath,@loader_path"}
		table.insert(ldflags, "-undefined")
		table.insert(ldflags, "dynamic_lookup")
		env = MacOSCross.env(ModuleUtil.MACOS_TC_BIN)
	end

	return {
		type = "compile_c",
		compiler = compiler,
		env = env,
		cflags = cflags,
		includes = {
			BuildConfig.getFfmpegDepsDir(target) .. "/include",
		},
		sources = {
			"aqua/bass/ffmpeg_plugin.c",
		},
		output = "${bin_dir}/" .. out_name,
		lib_dirs = lib_dirs,
		libs = libs,
		ldflags = ldflags,
	}
end

---@param target rizu.build.Target
---@return string[]
local function inputs(target)
	return {
		"aqua/bass/ffmpeg_plugin.c",
		BuildConfig.getFfmpegDepsDir(target) .. "/include/libavcodec/avcodec.h",
		ffmpegLibInput(target),
		"${bin_dir}/" .. BASS_OUTPUT_NAME[target],
	}
end

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
function BassFfmpegSpec.add(target, spec)
	local out_name = OUTPUT_NAME[target]
	if not out_name then
		return
	end

	table.insert(spec.steps, {
		id = "dep_bass_ffmpeg",
		kind = "source-build",
		outputs = {"${bin_dir}/" .. out_name},
		inputs = inputs(target),
		actions = {
			compileAction(target),
			{type = "assert_file", path = "${bin_dir}/" .. out_name},
		},
	})
end

return BassFfmpegSpec
