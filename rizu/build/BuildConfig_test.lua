local BuildConfig = require("rizu.build.BuildConfig")

local test = {}

function test.module_records_and_status_names(t)
	local names = BuildConfig.getModuleNames("windows")
	t:eq(names.video, "video.dll")
	t:eq(names.z7, "7z.dll")
	t:eq(names.minacalc, "minacalc.dll")
	t:eq(names.luamidi, "luamidi.dll")

	local outputs = BuildConfig.getModuleOutputs("windows", "build/artifacts/windows")
	t:eq(outputs.video, "build/artifacts/windows/video.dll")
	t:eq(outputs.z7, "build/artifacts/windows/7z.dll")
end

return test
