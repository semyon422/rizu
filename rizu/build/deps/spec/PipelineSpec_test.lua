local PipelineSpec = require("rizu.build.deps.spec.PipelineSpec")
local deps = require("rizu.build.deps.Manifest")

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
function test.pipeline_spec_includes_native_module_steps_for_all_targets(t)
	for _, target in ipairs({"linux", "windows", "macos"}) do
		local spec = PipelineSpec.load(target, deps)
		t:assert(findStep(spec, "module_z7_artifact") ~= nil)
		t:assert(findStep(spec, "module_video_artifact") ~= nil)
		t:assert(findStep(spec, "module_minacalc_artifact") ~= nil)
		t:assert(findStep(spec, "module_luamidi_artifact") ~= nil)
		t:assert(findStep(spec, "module_video_bin") ~= nil)
	end
end

---@param t testing.T
function test.macos_native_steps_use_osxcross_and_require_ffmpeg(t)
	local spec = PipelineSpec.load("macos", deps)
	local video = findStep(spec, "module_video_artifact")
	local luamidi = findStep(spec, "module_luamidi_artifact")

	t:assert(video)
	t:assert(luamidi)
	---@cast video -?
	---@cast luamidi -?


	t:tdeq(video.requires, {
		"tree/include/luajit-2.1/lua.h",
		"build/deps/local/macos/ffmpeg/include/libavcodec/avcodec.h",
		"build/deps/local/macos/ffmpeg/lib/libavcodec.dylib",
	})
	t:eq(video.actions[1].compiler, "${root_abs}/build/deps/osxcross/target/bin/x86_64-apple-darwin22.2-clang")
	t:eq(video.actions[1].env.PATH, "${root_abs}/build/deps/osxcross/target/bin:$PATH")
	t:eq(luamidi.actions[1].compiler, "${root_abs}/build/deps/osxcross/target/bin/x86_64-apple-darwin22.2-clang++")
	t:tdeq(luamidi.actions[1].ldflags, {"-framework", "CoreMIDI", "-framework", "CoreFoundation", "-framework", "CoreAudio", "-framework", "CoreServices"})
end

return test
