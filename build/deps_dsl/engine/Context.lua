local BuildConfig = require("build.BuildConfig")

local Context = {}

local function ensureBaseDirs(ctx, target)
	ctx.fs:createDirectory(BuildConfig.getDownloadsDir())
	ctx.fs:createDirectory(BuildConfig.getDepsDir())
	ctx.fs:createDirectory(BuildConfig.ROOT_DIRS.prebuilt)
	ctx.fs:createDirectory(BuildConfig.getPrebuiltDir(target))
	for _, dir in pairs(BuildConfig.TARGET_BIN_DIRS) do
		ctx.fs:createDirectory(dir)
	end
end

function Context.new(ctx, target, opts)
	local normalized_target = BuildConfig.normalizeTarget(target)
	local root_abs = ctx.shell:popen("pwd"):gsub("%s+$", "")
	local env = {
		ctx = ctx,
		target = normalized_target,
		root_abs = root_abs,
		bin_dir = BuildConfig.getBinDir(normalized_target),
		downloads_dir = BuildConfig.getDownloadsDir(),
		deps_dir = BuildConfig.getDepsDir(),
		prebuilt_dir = BuildConfig.getPrebuiltDir(normalized_target),
		bin_dirs = BuildConfig.TARGET_BIN_DIRS,
	}

	if not opts or opts.initialize_dirs ~= false then
		ensureBaseDirs(ctx, normalized_target)
	end

	return env
end

function Context.interpolate(env, value)
	if type(value) ~= "string" then
		return value
	end
	local vars = {
		target = env.target,
		root_abs = env.root_abs,
		bin_dir = env.bin_dir,
		downloads_dir = env.downloads_dir,
		deps_dir = env.deps_dir,
		prebuilt_dir = env.prebuilt_dir,
		bin_linux = env.bin_dirs.linux,
		bin_windows = env.bin_dirs.windows,
		bin_macos = env.bin_dirs.macos,
	}
	return (value:gsub("${([%w_]+)}", function(k)
		return vars[k] or ""
	end))
end

return Context
