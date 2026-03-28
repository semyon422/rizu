local BuildConfig = require("build.BuildConfig")

local Env = {}

function Env.new(ctx, target, deps, opts)
	local normalized_target = (target or "linux"):lower()
	local root_abs = ctx.shell:popen("pwd"):gsub("%s+$", "")
	local platform_bin_map = BuildConfig.TARGET_BIN_DIRS
	local initialize_dirs = opts == nil or opts.initialize_dirs ~= false
	local env = {
		ctx = ctx,
		target = normalized_target,
		deps = deps,
		root_abs = root_abs,
		platform_bin_map = platform_bin_map,
		platform_bin = BuildConfig.getBinDir(normalized_target),
	}

	if initialize_dirs then
		ctx.fs:createDirectory("build/downloads")
		ctx.fs:createDirectory("build/deps")
		ctx.fs:createDirectory("build/downloads/prebuilt")
		ctx.fs:createDirectory("build/downloads/prebuilt/" .. normalized_target)
		for _, bin_dir in pairs(platform_bin_map) do
			ctx.fs:createDirectory(bin_dir)
		end
	end

	return env
end

function Env.ensure_source_dep(env, config)
	local ctx = env.ctx
	local dest = "build/downloads/" .. config.archive
	local extract_to = "build/deps/" .. config.dir
	if not ctx.fs:getInfo(extract_to) then
		if not ctx.fs:getInfo(dest) or ctx.fs:getInfo(dest).size == 0 then
			ctx.downloader:download(config.url, dest)
		end
		ctx.fs:createDirectory(extract_to)
		if config.archive:match("%.tar%.gz$") or config.archive:match("%.tgz$") then
			ctx.shell:execute(string.format("tar -xzf %q -C %q --strip-components=1", dest, extract_to))
		elseif config.archive:match("%.tar%.xz$") then
			ctx.shell:execute(string.format("tar -xf %q -C %q --strip-components=1", dest, extract_to))
		else
			error("Unsupported source archive format: " .. config.archive)
		end
	end
	return extract_to
end

function Env.ensure_dd_wrapper(env)
	local ctx = env.ctx
	local dd_wrapper = "build/deps/dd32.sh"
	if not ctx.fs:getInfo(dd_wrapper) then
		ctx.shell:execute(string.format("bash -lc 'cat > %q <<\"EOF\"\n#!/bin/sh\ncat | head -c 32\nEOF'", dd_wrapper))
		ctx.shell:execute(string.format("chmod +x %q", dd_wrapper))
	end
	return env.root_abs .. "/" .. dd_wrapper
end

function Env.resolve_macos_toolchain(env)
	local ctx = env.ctx
	local root_abs = env.root_abs
	local bin_dir = "build/deps/osxcross/target/bin"
	local direct = "x86_64-apple-darwin22.2"
	if ctx.fs:getInfo(bin_dir .. "/" .. direct .. "-clang") then
		return {
			cc = root_abs .. "/" .. bin_dir .. "/" .. direct .. "-clang",
			ar = root_abs .. "/" .. bin_dir .. "/" .. direct .. "-ar",
			ranlib = root_abs .. "/" .. bin_dir .. "/" .. direct .. "-ranlib",
			install_name_tool = root_abs .. "/" .. bin_dir .. "/" .. direct .. "-install_name_tool",
			host = direct,
		}
	end
	local bins = ctx.fs:getDirectoryItems(bin_dir) or {}
	for _, b in ipairs(bins) do
		if b:match("^x86_64%-apple%-darwin[%d%.]+%-clang$") then
			local host = b:gsub("%-clang$", "")
			return {
				cc = root_abs .. "/" .. bin_dir .. "/" .. b,
				ar = root_abs .. "/" .. bin_dir .. "/" .. host .. "-ar",
				ranlib = root_abs .. "/" .. bin_dir .. "/" .. host .. "-ranlib",
				install_name_tool = root_abs .. "/" .. bin_dir .. "/" .. host .. "-install_name_tool",
				host = host,
			}
		end
	end
	return nil
end

return Env
