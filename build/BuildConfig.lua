local BuildConfig = {}

BuildConfig.TARGET_BIN_DIRS = {
	linux = "bin/linux64",
	windows = "bin/win64",
	macos = "bin/mac64",
}

BuildConfig.TARGET_ARTIFACT_DIRS = {
	linux = "build/artifacts/linux",
	windows = "build/artifacts/windows",
	macos = "build/artifacts/macos",
}

BuildConfig.MODULE_OUTPUT_NAMES = {
	linux = {
		z7 = "lib7z.so",
		video = "video.so",
		minacalc = "libminacalc.so",
		luamidi = "luamidi.so",
	},
	windows = {
		z7 = "7z.dll",
		video = "video.dll",
		minacalc = "minacalc.dll",
		luamidi = "luamidi.dll",
	},
	macos = {
		z7 = "lib7z.dylib",
		video = "video.so",
		minacalc = "libminacalc.dylib",
		luamidi = "luamidi.dylib",
	},
}

BuildConfig.MODULE_STATUS_NAMES = {
	linux = {
		z7 = "lib7z",
		video = "video",
		minacalc = "minacalc",
		luamidi = "luamidi",
	},
	windows = {
		z7 = "7z",
		video = "video",
		minacalc = "minacalc",
		luamidi = "luamidi",
	},
	macos = {
		z7 = "lib7z",
		video = "video",
		minacalc = "minacalc",
		luamidi = "luamidi",
	},
}

BuildConfig.MODULE_SPECS = {
	{key = "video", source = "aqua/video.c"},
	{key = "z7", source = "aqua/7z.c"},
	{key = "minacalc", source = "build/deps/minacalc"},
	{key = "luamidi", source = "build/deps/luamidi"},
}

function BuildConfig.normalizeTarget(target)
	return (target or "linux"):lower()
end

function BuildConfig.getBinDir(target)
	local t = BuildConfig.normalizeTarget(target)
	return BuildConfig.TARGET_BIN_DIRS[t] or BuildConfig.TARGET_BIN_DIRS.linux
end

function BuildConfig.getArtifactsDir(target)
	local t = BuildConfig.normalizeTarget(target)
	return BuildConfig.TARGET_ARTIFACT_DIRS[t] or BuildConfig.TARGET_ARTIFACT_DIRS.linux
end

function BuildConfig.getModuleNames(target)
	local t = BuildConfig.normalizeTarget(target)
	return BuildConfig.MODULE_OUTPUT_NAMES[t] or BuildConfig.MODULE_OUTPUT_NAMES.linux
end

function BuildConfig.getModuleOutputs(target, out_dir)
	local outputs = {}
	local names = BuildConfig.getModuleNames(target)
	for key, name in pairs(names) do
		outputs[key] = out_dir .. "/" .. name
	end
	return outputs
end

function BuildConfig.getModuleStatusName(target, key)
	local t = BuildConfig.normalizeTarget(target)
	local names = BuildConfig.MODULE_STATUS_NAMES[t] or BuildConfig.MODULE_STATUS_NAMES.linux
	return names[key] or key
end

function BuildConfig.getModuleRecords(target, outputs, bin_dir)
	local names = BuildConfig.getModuleNames(target)
	local records = {}
	for _, spec in ipairs(BuildConfig.MODULE_SPECS) do
		table.insert(records, {
			key = spec.key,
			source = spec.source,
			artifact = outputs[spec.key],
			bin = bin_dir .. "/" .. names[spec.key],
		})
	end
	return records
end

return BuildConfig
