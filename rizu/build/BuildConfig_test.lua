local BuildConfig = require("rizu.build.BuildConfig")

local test = {}

function test.bin_and_artifacts_dirs(t)
	t:eq(BuildConfig.getBinDir("linux"), "bin/linux64")
	t:eq(BuildConfig.getBinDir("windows"), "bin/win64")
	t:eq(BuildConfig.getBinDir("macos"), "bin/mac64")
	t:eq(BuildConfig.getArtifactsDir("linux"), "build/artifacts/linux")
	t:eq(BuildConfig.getArtifactsDir("windows"), "build/artifacts/windows")
	t:eq(BuildConfig.getArtifactsDir("macos"), "build/artifacts/macos")
end

function test.module_outputs(t)
	local linux_out = BuildConfig.getModuleOutputs("linux", "build/artifacts/linux")
	t:eq(linux_out.z7, "build/artifacts/linux/lib7z.so")
	t:eq(linux_out.video, "build/artifacts/linux/video.so")
	t:eq(linux_out.minacalc, "build/artifacts/linux/libminacalc.so")
	t:eq(linux_out.luamidi, "build/artifacts/linux/luamidi.so")

	local win_out = BuildConfig.getModuleOutputs("windows", "build/artifacts/windows")
	t:eq(win_out.z7, "build/artifacts/windows/7z.dll")
	t:eq(win_out.video, "build/artifacts/windows/video.dll")
	t:eq(win_out.minacalc, "build/artifacts/windows/minacalc.dll")
	t:eq(win_out.luamidi, "build/artifacts/windows/luamidi.dll")

	local mac_out = BuildConfig.getModuleOutputs("macos", "build/artifacts/macos")
	t:eq(mac_out.z7, "build/artifacts/macos/lib7z.dylib")
	t:eq(mac_out.video, "build/artifacts/macos/video.so")
	t:eq(mac_out.minacalc, "build/artifacts/macos/libminacalc.dylib")
	t:eq(mac_out.luamidi, "build/artifacts/macos/luamidi.dylib")
end

function test.module_records_and_status_names(t)
	local out = BuildConfig.getModuleOutputs("windows", "build/artifacts/windows")
	local records = BuildConfig.getModuleRecords("windows", out, "bin/win64")
	t:eq(#records, 4)
	t:eq(records[1].key, "video")
	t:eq(records[1].source, "aqua/video.c")
	t:eq(records[1].bin, "bin/win64/video.dll")
	t:eq(records[2].key, "z7")
	t:eq(records[2].source, "aqua/7z.c")
	t:eq(records[2].bin, "bin/win64/7z.dll")
	t:eq(BuildConfig.getModuleStatusName("linux", "z7"), "lib7z")
	t:eq(BuildConfig.getModuleStatusName("windows", "z7"), "7z")
end

return test
