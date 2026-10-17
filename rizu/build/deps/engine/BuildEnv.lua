local BuildConfig = require("rizu.build.BuildConfig")

---@class rizu.build.deps.engine.BuildEnv
local BuildEnv = {}

---@param ctx rizu.build.Context
local function ensureBaseDirs(ctx)
	ctx.fs:createDirectory(BuildConfig.getDownloadsDir())
	ctx.fs:createDirectory(BuildConfig.getDepsDir())
	for _, dir in pairs(BuildConfig.TARGET_BIN_DIRS) do
		ctx.fs:createDirectory(dir)
	end
end

---@param ctx rizu.build.Context
---@param target rizu.build.Target
---@param opts? { initialize_dirs?: boolean }
---@return rizu.build.deps.Env
function BuildEnv.new(ctx, target, opts)
	local env = {
		ctx = ctx,
		target = target,
		root_abs = ctx.fs:getWorkingDirectory(),
		bin_dir = BuildConfig.getBinDir(target),
		downloads_dir = BuildConfig.getDownloadsDir(),
		deps_dir = BuildConfig.getDepsDir(),
		bin_dirs = BuildConfig.TARGET_BIN_DIRS,
	}

	if not opts or opts.initialize_dirs ~= false then
		ensureBaseDirs(ctx)
	end

	return env
end

---@param env rizu.build.deps.Env
---@param value any
---@return any
function BuildEnv.interpolate(env, value)
	if type(value) ~= "string" then
		return value
	end
	local vars = {
		target = env.target,
		root_abs = env.root_abs,
		bin_dir = env.bin_dir,
		downloads_dir = env.downloads_dir,
		deps_dir = env.deps_dir,
		bin_linux = env.bin_dirs.linux,
		bin_windows = env.bin_dirs.windows,
		bin_macos = env.bin_dirs.macos,
	}
	return (value:gsub("${([%w_]+)}", function(k)
		return vars[k] or ""
	end))
end

return BuildEnv
