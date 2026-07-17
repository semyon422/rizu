---@class rizu.build.BuildConfig
local BuildConfig = {}

---@type rizu.build.Target[]
BuildConfig.TARGETS = {"linux", "windows", "macos"}

---@type {[rizu.build.Target]: string}
BuildConfig.TARGET_BIN_DIRS = {
	linux = "bin/linux64",
	windows = "bin/win64",
	macos = "bin/mac64",
}

---@type {[rizu.build.Target]: string}
BuildConfig.TARGET_ARTIFACT_DIRS = {
	linux = "build/artifacts/linux",
	windows = "build/artifacts/windows",
	macos = "build/artifacts/macos",
}

---@type {downloads: string, deps: string}
BuildConfig.ROOT_DIRS = {
	downloads = "build/downloads",
	deps = "build/deps",
}

---@type {[rizu.build.Target]: {[string]: string}}
BuildConfig.MODULE_OUTPUT_NAMES = {
	linux = {
		z7 = "lib7z.so",
		video = "video.so",
		minacalc = "libminacalc.so",
		luamidi = "luamidi.so",
		needle = "libneedle_runtime.so",
	},
	windows = {
		z7 = "7z.dll",
		video = "video.dll",
		minacalc = "minacalc.dll",
		luamidi = "luamidi.dll",
		needle = "needle_runtime.dll",
	},
	macos = {
		z7 = "lib7z.dylib",
		video = "video.so",
		minacalc = "libminacalc.dylib",
		luamidi = "luamidi.dylib",
		needle = "libneedle_runtime.dylib",
	},
}

---@param target rizu.build.Target
---@return string
function BuildConfig.getBinDir(target)
	return BuildConfig.TARGET_BIN_DIRS[target]
end

---@param target rizu.build.Target
---@return string
function BuildConfig.getArtifactsDir(target)
	return BuildConfig.TARGET_ARTIFACT_DIRS[target]
end

---@param target rizu.build.Target
---@return {[string]: string}
function BuildConfig.getModuleNames(target)
	return BuildConfig.MODULE_OUTPUT_NAMES[target]
end

---@param target rizu.build.Target
---@param out_dir string
---@return {[string]: string}
function BuildConfig.getModuleOutputs(target, out_dir)
	---@type {[string]: string}
	local outputs = {}
	local names = BuildConfig.getModuleNames(target)
	for key, name in pairs(names) do
		outputs[key] = out_dir .. "/" .. name
	end
	return outputs
end

---@return string
function BuildConfig.getDownloadsDir()
	return BuildConfig.ROOT_DIRS.downloads
end

---@return string
function BuildConfig.getDepsDir()
	return BuildConfig.ROOT_DIRS.deps
end

--- Dependency sub-directory paths (relative to deps dir)

---@type {[rizu.build.Target]: string}
BuildConfig.FFMPEG_DEPS_DIRS = {
	linux = "ffmpeg-linux",
	windows = "ffmpeg-win",
	macos = "local/macos/ffmpeg",
}

---@param target rizu.build.Target
---@return string
function BuildConfig.getFfmpegDepsDir(target)
	return BuildConfig.ROOT_DIRS.deps .. "/" .. BuildConfig.FFMPEG_DEPS_DIRS[target]
end

---@return string
function BuildConfig.getSevenZipSdkDir()
	return BuildConfig.ROOT_DIRS.deps .. "/7zsdk"
end

---@return string
function BuildConfig.getMinacalcDepsDir()
	return BuildConfig.ROOT_DIRS.deps .. "/minacalc"
end

---@return string
function BuildConfig.getLuamidiDepsDir()
	return BuildConfig.ROOT_DIRS.deps .. "/luamidi"
end

---@return string
function BuildConfig.getOsxcrossToolchainBin()
	return BuildConfig.ROOT_DIRS.deps .. "/osxcross/target/bin"
end

---@param target rizu.build.Target
---@return string
function BuildConfig.getLocalPrefixDir(target)
	return "local/" .. target
end

return BuildConfig
