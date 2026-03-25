local class = require("class")

---@class build.tasks.SetupCrossMacOS
local SetupCrossMacOS = class()

function SetupCrossMacOS:new()
	self.name = "setup_cross_macos"
	self.deps = {}
end

function SetupCrossMacOS:run(ctx)
	local build_dir = "build"
	local downloads_dir = build_dir .. "/downloads"
	local osxcross_dir = build_dir .. "/osxcross"
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
		ctx.shell:execute("git clone https://github.com/tpoechtrager/osxcross " .. osxcross_dir)
	end

	-- 3. Generate the SDK package
	local sdk_tarball = osxcross_dir .. "/tarballs/MacOSX" .. sdk_version .. ".sdk.tar.xz"
	if not ctx.fs:getInfo(sdk_tarball) then
		print("Extracting MacOS SDK from .xip...")
		-- Note: We assume tools/gen_sdk_package_pbzx.sh is available in cloned osxcross
		ctx.shell:execute(string.format("cd %s && ./tools/gen_sdk_package_pbzx.sh ../downloads/Xcode_14.2.xip", osxcross_dir))
		ctx.shell:execute(string.format("mv %s/MacOSX%s.sdk.tar.xz %s/tarballs/", osxcross_dir, sdk_version, osxcross_dir))
	end

	-- 4. Build osxcross
	print("Building osxcross (UNATTENDED=1)...")
	ctx.shell:execute("cd " .. osxcross_dir .. " && UNATTENDED=1 ./build.sh")

	print("---------------------------------------------------")
	print("MacOS Cross-Compilation Setup Complete!")
	print("---------------------------------------------------")
	print("To use the toolchain, add the following to your PATH:")
	print("export PATH=$PATH:" .. ctx.root .. "/" .. osxcross_dir .. "/target/bin")
	print("---------------------------------------------------")
end

return SetupCrossMacOS
