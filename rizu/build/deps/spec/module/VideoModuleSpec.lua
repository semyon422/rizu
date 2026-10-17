local BuildConfig = require("rizu.build.BuildConfig")
local ModuleUtil = require("rizu.build.deps.spec.module.ModuleUtil")

---@class rizu.build.deps.spec.module.VideoModuleSpec
local VideoModuleSpec = {}

---@param target rizu.build.Target
---@param artifact string
---@return rizu.build.deps.Action
local function videoCompileAction(target, artifact)
	local compiler = "gcc"
	local cflags = {"-shared", "-fPIC", "-Wl,-rpath,'$ORIGIN'"}
	local lib_dirs = {BuildConfig.getFfmpegDepsDir(target) .. "/lib"}
	---@type {[string]: string}?
	local env
	if target == "windows" then
		compiler = ModuleUtil.CC_BY_TARGET.windows
		cflags = {"-shared", "-fPIC"}
		lib_dirs = {"tree/lib", BuildConfig.getFfmpegDepsDir(target) .. "/lib"}
	elseif target == "macos" then
		compiler = ModuleUtil.CC_BY_TARGET.macos
		env = ModuleUtil.ENV_BY_TARGET.macos
		cflags = {"-shared", "-fPIC", "-undefined", "dynamic_lookup", "-Wl,-rpath,@loader_path"}
		lib_dirs = {BuildConfig.getFfmpegDepsDir(target) .. "/lib"}
	end

	local libs = {"avformat", "avcodec", "swscale", "avutil", "m"}
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
			BuildConfig.getFfmpegDepsDir(target) .. "/include",
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
			BuildConfig.getFfmpegDepsDir(target) .. "/include/libavcodec/avcodec.h",
			BuildConfig.getFfmpegDepsDir(target) .. "/lib/libavcodec.dll.a",
		}
	elseif target == "macos" then
		return {
			"tree/include/luajit-2.1/lua.h",
			BuildConfig.getFfmpegDepsDir(target) .. "/include/libavcodec/avcodec.h",
			BuildConfig.getFfmpegDepsDir(target) .. "/lib/libavcodec.dylib",
		}
	end
	return {
		"tree/include/luajit-2.1/lua.h",
		BuildConfig.getFfmpegDepsDir(target) .. "/include/libavcodec/avcodec.h",
		BuildConfig.getFfmpegDepsDir(target) .. "/lib/libavcodec.so.62",
	}
end

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
function VideoModuleSpec.add(target, spec)
	local artifact_dir = BuildConfig.getArtifactsDir(target)
	local bin_dir = BuildConfig.getBinDir(target)
	local outputs = BuildConfig.getModuleOutputs(target, artifact_dir)
	local names = BuildConfig.getModuleNames(target)

	local artifact = outputs.video
	local bin_file = bin_dir .. "/" .. names.video

	local compile_id = ModuleUtil.makeStepIds("video")
	local required_inputs = videoRequires(target)
	local inputs = {"aqua/video.c"}
	for _, req in ipairs(required_inputs) do
		table.insert(inputs, req)
	end

	ModuleUtil.addStep(spec, {
		id = compile_id,
		kind = "source-build",
		status_label = "Video Artifact",
		outputs = {artifact},
		inputs = inputs,
		actions = {videoCompileAction(target, artifact)},
	})

	ModuleUtil.addPublishStep(spec, "video", "Video", artifact, bin_file)
end

return VideoModuleSpec
