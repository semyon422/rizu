local DependencySpec = require("rizu.build.deps.spec.DependencySpec")
local BuildEnv = require("rizu.build.deps.engine.BuildEnv")
local Executor = require("rizu.build.deps.engine.Executor")
local deps = require("rizu.build.deps.Manifest")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@param spec rizu.build.deps.Spec
---@param id string
---@return rizu.build.deps.Step?
local function findStep(spec, id)
	for _, step in ipairs(spec.steps) do
		if step.id == id then
			return step
		end
	end
	return nil
end

---@param t testing.T
function test.loads_normalized_valid_specs_for_all_targets(t)
	for _, target in ipairs({"linux", "windows", "macos"}) do
		local spec = DependencySpec.load(target, deps)
		t:eq(spec.target, target)
		t:assert(#spec.steps > 0)
		t:assert(#spec.outputs > 0)

		for _, step in ipairs(spec.steps) do
			t:assert(type(step.outputs) == "table")
			t:assert(type(step.inputs) == "table")
			t:assert(type(step.status_label) == "string")
		end
	end
end

---@param t testing.T
function test.rejects_unknown_target(t)
	local ok, err = pcall(function()
		DependencySpec.load("plan9", deps)
	end)
	t:eq(ok, false)
	t:assert(tostring(err):find("No dependency spec builder for target: plan9", 1, true) ~= nil, tostring(err))
end

---@param t testing.T
function test.includes_native_module_steps_for_all_targets(t)
	for _, target in ipairs({"linux", "windows", "macos"}) do
		local spec = DependencySpec.load(target, deps)
		t:assert(findStep(spec, "module_z7_artifact") ~= nil)
		t:assert(findStep(spec, "module_video_artifact") ~= nil)
		t:assert(findStep(spec, "module_minacalc_artifact") ~= nil)
		t:assert(findStep(spec, "module_luamidi_artifact") ~= nil)
		t:assert(findStep(spec, "module_video_bin") ~= nil)
	end
end

---@param t testing.T
function test.macos_native_steps_use_osxcross_and_track_ffmpeg_inputs(t)
	local spec = DependencySpec.load("macos", deps)
	local video = findStep(spec, "module_video_artifact")
	local luamidi = findStep(spec, "module_luamidi_artifact")

	t:assert(video)
	t:assert(luamidi)
	---@cast video -?
	---@cast luamidi -?

	t:tdeq(video.inputs, {
		"aqua/video.c",
		"tree/include/luajit-2.1/lua.h",
		"build/deps/local/macos/ffmpeg/include/libavcodec/avcodec.h",
		"build/deps/local/macos/ffmpeg/lib/libavcodec.dylib",
	})
	t:eq(video.actions[1].compiler, "${root_abs}/build/deps/osxcross/target/bin/x86_64-apple-darwin22.2-clang")
	t:eq(video.actions[1].env.PATH, "${root_abs}/build/deps/osxcross/target/bin:$PATH")
	t:eq(luamidi.actions[1].compiler, "${root_abs}/build/deps/osxcross/target/bin/x86_64-apple-darwin22.2-clang++")
	t:tdeq(luamidi.actions[1].ldflags, {"-framework", "CoreMIDI", "-framework", "CoreFoundation", "-framework", "CoreAudio", "-framework", "CoreServices"})
end

---@param t testing.T
function test.ffmpeg_binary_reruns_extract_when_output_missing(t)
	local fs = FakeFilesystem()
	fs:setWorkingDirectory("/repo")
	fs:createDirectory("build/deps/ffmpeg-linux")

	local exec = {}
	local shell = {}
	function shell:execute(cmd)
		table.insert(exec, cmd)
		if cmd:find("tar %-%-touch %-xf") then
			fs:createDirectory("build/deps/ffmpeg-linux/lib")
			for _, name in ipairs({
				"libavcodec.so.62",
				"libavdevice.so.62",
				"libavfilter.so.11",
				"libavformat.so.62",
				"libavutil.so.60",
				"libswresample.so.6",
				"libswscale.so.9",
			}) do
				fs:write("build/deps/ffmpeg-linux/lib/" .. name, "x")
			end
		end
		return true
	end
	function shell:popen() return "" end

	local downloader = {}
	function downloader:download(_url, dest)
		fs:write(dest, "archive")
	end

	local spec = DependencySpec.load("linux", deps)
	local step = findStep(spec, "ffmpeg_binary")
	t:assert(step)
	---@cast step -?

	Executor.runStep(BuildEnv.new({fs = fs, shell = shell, downloader = downloader}, "linux"), step)

	local extracted = false
	for _, cmd in ipairs(exec) do
		if cmd:find("tar %-%-touch %-xf") then
			extracted = true
			break
		end
	end
	t:assert(extracted, "ffmpeg extract should repair partial extract directories")
end

---@param t testing.T
function test.sevenzip_sdk_uses_host_tar_extractor(t)
	local spec = DependencySpec.load("linux", deps)
	local step = findStep(spec, "sevenzip_sdk")
	t:assert(step)
	---@cast step -?

	t:eq(step.actions[1].dest, "${downloads_dir}/7z2501-src.tar.xz")
	t:eq(step.actions[2].format, "tar.xz")
	t:eq(step.actions[2].strip_components, 0)
	t:tdeq(step.outputs, {
		"${deps_dir}/7zsdk/C/Alloc.c",
		"${deps_dir}/7zsdk/C/LzmaLib.c",
	})
end

---@param t testing.T
function test.sevenzip_native_module_tracks_sdk_sources_as_inputs(t)
	local spec = DependencySpec.load("linux", deps)
	local step = findStep(spec, "module_z7_artifact")
	t:assert(step)
	---@cast step -?

	t:tdeq(step.inputs, {
		"aqua/7z.c",
		"build/deps/7zsdk/C/Alloc.c",
		"build/deps/7zsdk/C/LzmaLib.c",
	})
end

---@param t testing.T
function test.love_windows_uses_deps_scratch_dirs(t)
	local spec = DependencySpec.load("linux", deps)
	local step = findStep(spec, "love_win")
	t:assert(step)
	---@cast step -?

	local saw_finish_cleanup = false
	for _, action in ipairs(step.actions) do
		for _, key in ipairs({"dest", "path", "pattern", "src"}) do
			local value = action[key]
			if type(value) == "string" then
				t:assert(value:find("bin/win64%-tmp") == nil, value)
				t:assert(value:find("bin/win64%-outer%-tmp") == nil, value)
				t:assert(value:find("bin/win64%-inner%-tmp") == nil, value)
			end
		end
		if action.type == "remove" and action.path == "${deps_dir}/love-win-outer-tmp" then
			saw_finish_cleanup = true
		end
	end

	t:eq(saw_finish_cleanup, true)
end

return test
