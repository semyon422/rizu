local BuildConfig = require("rizu.build.BuildConfig")

local test = {}

function test.unknown_targets_fall_back_to_linux_defaults(t)
	t:eq(BuildConfig.getBinDir("plan9"), BuildConfig.getBinDir("linux"))
	t:eq(BuildConfig.getArtifactsDir("plan9"), BuildConfig.getArtifactsDir("linux"))

	local fallback_outputs = BuildConfig.getModuleOutputs("plan9", "out")
	local linux_outputs = BuildConfig.getModuleOutputs("linux", "out")
	t:tdeq(fallback_outputs, linux_outputs)
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
