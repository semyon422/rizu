local ITask = require("rizu.build.ITask")

---@class rizu.build.tasks.SetupHostTask: rizu.build.ITask
---@operator call: rizu.build.tasks.SetupHostTask
---@field name string
---@field deps string[]
local SetupHostTask = ITask + {}

function SetupHostTask:new()
	self.name = "setup_host"
	self.deps = {}
end

---@param ctx rizu.build.Context
function SetupHostTask:run(ctx)
	print("Updating package list...")
	ctx.shell:execute("sudo apt-get update")

	print("Installing system packages...")
	local packages = {
		"build-essential",
		"gcc-mingw-w64-x86-64",
		"g++-mingw-w64-x86-64",
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
		"libasound2-dev",
		"git",
		"xz-utils",
		"cpio",
		"zlib1g-dev",
		"libbz2-dev",
		"xar",
	}
	ctx.shell:execute("sudo apt-get install -y " .. table.concat(packages, " "))
	print("Host setup complete.")
end

---@param ctx rizu.build.Context
---@return rizu.build.StatusRow[]
function SetupHostTask:getStatus(ctx)
	local required_bins = {
		"gcc",
		"g++",
		"x86_64-w64-mingw32-gcc",
		"x86_64-w64-mingw32-g++",
		"clang",
		"cmake",
		"curl",
		"unzip",
		"git",
	}

	for _, bin in ipairs(required_bins) do
		local present = ctx.shell:popen("command -v " .. bin .. " >/dev/null && echo OK || echo MISSING")
		if not present or not present:match("OK") then
			return {{name = "Host Environment", value = "MISSING (" .. bin .. ")"}}
		end
	end

	return {{name = "Host Environment", value = "READY"}}
end

return SetupHostTask
