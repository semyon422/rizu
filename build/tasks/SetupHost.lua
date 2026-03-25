local class = require("class")

---@class build.tasks.SetupHost
local SetupHost = class()

function SetupHost:new()
	self.name = "setup_host"
	self.deps = {}
end

function SetupHost:run(ctx)
	print("Updating package list...")
	ctx.shell:execute("sudo apt-get update")

	print("Installing system packages...")
	local packages = {
		"build-essential",
		"gcc-mingw-w64-x86-64",
		"clang",
		"cmake",
		"patch",
		"libssl-dev",
		"liblzma-dev",
		"libxml2-dev",
		"curl",
		"unzip",
		"tar",
		"wget",
		"p7zip-full",
		"libasound2-dev",
		"git",
		"xz-utils",
		"cpio",
		"libxml2-dev",
		"libssl-dev",
		"zlib1g-dev",
		"libbz2-dev",
		"xar",
	}
	ctx.shell:execute("sudo apt-get install -y " .. table.concat(packages, " "))
	print("Host setup complete.")
end

function SetupHost:getStatus(ctx)
	return {{ name = "Host Environment", value = "READY" }}
end

return SetupHost
