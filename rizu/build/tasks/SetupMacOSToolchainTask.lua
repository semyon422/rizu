local ITask = require("rizu.build.ITask")

---@class rizu.build.tasks.SetupMacOSToolchainTask: rizu.build.ITask
---@operator call: rizu.build.tasks.SetupMacOSToolchainTask
---@field name string
---@field deps string[]
local SetupMacOSToolchainTask = ITask + {}

local function getCompilerPath()
	return "build/deps/osxcross/target/bin/x86_64-apple-darwin22.2-clang"
end

function SetupMacOSToolchainTask:new()
	self.name = "setup_macos_toolchain"
	self.deps = {}
end

---@param ctx rizu.build.Context
function SetupMacOSToolchainTask:run(ctx)
	local compiler = getCompilerPath()
	if ctx.fs:getInfo(compiler) then
		print("macOS toolchain already present: " .. compiler)
		return
	end

	local build_dir = "build"
	local deps_dir = build_dir .. "/deps"
	local downloads_dir = build_dir .. "/downloads"
	local osxcross_dir = deps_dir .. "/osxcross"
	local sdk_xip = downloads_dir .. "/Xcode_14.2.xip"
	local sdk_version = "13.1"

	print("---------------------------------------------------")
	print("Setting up MacOS Cross-Compilation (osxcross)...")
	print("---------------------------------------------------")

	-- 1. Check for Xcode SDK
	if not ctx.fs:getInfo(sdk_xip) then
		error("Xcode SDK not found at " .. sdk_xip .. ". Please place Xcode_14.2.xip in build/downloads/")
	end

	-- 2. Clone osxcross
	if not ctx.fs:getInfo(osxcross_dir) then
		print("Cloning osxcross...")
		ctx.fs:createDirectory(deps_dir)
		ctx.shell:execute("git clone https://github.com/tpoechtrager/osxcross " .. osxcross_dir)
	end
	-- Ensure osxcross submodules are present (needed for build/xar/xar and pbzx sources).
	ctx.shell:execute(string.format("git -C %s submodule update --init --recursive", osxcross_dir))

	-- osxcross manages the xar and pbzx helper builds internally.

	-- 3. Generate the SDK package
	local sdk_tarball = osxcross_dir .. "/tarballs/MacOSX" .. sdk_version .. ".sdk.tar.xz"
	if not ctx.fs:getInfo(sdk_tarball) then
		print("Extracting MacOS SDK from .xip (this might take a while)...")
		local root_abs = ctx.fs:getWorkingDirectory()
		local full_osxcross_dir = root_abs .. "/" .. osxcross_dir
		local xip_abs = root_abs .. "/build/downloads/Xcode_14.2.xip"

		-- Use our built tools
		local env = string.format("PATH=%s/target/bin:$PATH", full_osxcross_dir)
		ctx.shell:execute(string.format(
			"%s bash -lc 'cd %q && source tools/tools.sh && mkdir -p \"$BUILD_DIR\" && cd \"$BUILD_DIR\" && build_xar && build_pbxz'",
			env,
			osxcross_dir
		))
		local ok = ctx.shell:execute(string.format(
			"./rizu/build/scripts/package_macos_sdk.sh %q %q %q %q",
			full_osxcross_dir,
			xip_abs,
			sdk_version,
			root_abs .. "/" .. sdk_tarball
		))
		if not ok then
			error("Failed to generate SDK package.")
		end

		-- The script might leave multiple versions if Xcode contains them (e.g. 13 and 13.1)
		print("Ensuring SDK is in tarballs/...")
		ctx.shell:execute(string.format("mv %s/MacOSX*.sdk.tar.xz %s/tarballs/ 2>/dev/null", osxcross_dir, osxcross_dir))

		-- If multiple SDKs found, build.sh fails. Keep only the requested version.
		local items = ctx.fs:getDirectoryItems(osxcross_dir .. "/tarballs") or {}
		for _, item in ipairs(items) do
			if item:match("^MacOSX.*%.sdk%.tar%.xz$") and not item:match("MacOSX" .. sdk_version) then
				print("Removing redundant SDK:", item)
				ctx.fs:remove(osxcross_dir .. "/tarballs/" .. item)
			end
		end
	end

	-- 4. Build osxcross
	print("Building osxcross (UNATTENDED=1)...")
	local ok = ctx.shell:execute(string.format("cd %s && UNATTENDED=1 SDK_VERSION=%s ./build.sh", osxcross_dir, sdk_version))
	if not ok then
		error("osxcross build failed. Check logs in " .. osxcross_dir)
	end

	print("---------------------------------------------------")
	print("MacOS Cross-Compilation Setup Complete!")
	print("---------------------------------------------------")
	print("To use the toolchain, add the following to your PATH:")
	print("export PATH=$PATH:" .. ctx.fs:getWorkingDirectory() .. "/" .. osxcross_dir .. "/target/bin")
	print("---------------------------------------------------")
end

---@param ctx rizu.build.Context
---@return rizu.build.StatusRow[]
function SetupMacOSToolchainTask:getStatus(ctx)
	local osxcross_dir = "build/deps/osxcross"
	-- Check for the specific compiler version used by the build pipeline.
	local compiler = getCompilerPath()
	local exists = ctx.fs:getInfo(compiler) and "READY" or "MISSING"

	return {{name = "macOS Toolchain", value = exists}}
end

---@param ctx rizu.build.Context
---@return boolean
function SetupMacOSToolchainTask:upToDate(ctx)
	return ctx.fs:getInfo(getCompilerPath()) ~= nil
end

return SetupMacOSToolchainTask
