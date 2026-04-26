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

BuildConfig.ROOT_DIRS = {
	downloads = "build/downloads",
	deps = "build/deps",
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

function BuildConfig.getDownloadsDir()
	return BuildConfig.ROOT_DIRS.downloads
end

function BuildConfig.getDepsDir()
	return BuildConfig.ROOT_DIRS.deps
end

return BuildConfig
