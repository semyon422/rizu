local SetupMacOSToolchainTask = require("rizu.build.tasks.SetupMacOSToolchainTask")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

---@param t testing.T
function test.packages_only_required_sdk_files(t)
	local fs = FakeFilesystem()
	fs:setWorkingDirectory("/repo")
	fs:createDirectory("build/deps/osxcross")
	fs:createDirectory("build/downloads")
	fs:write("build/downloads/Xcode_14.2.xip", "x")

	local commands = {}
	---@type rizu.build.IShell
	local shell = {}
	function shell:execute(command)
		table.insert(commands, command)
		return true
	end
	function shell:popen()
		return ""
	end

	SetupMacOSToolchainTask():run({fs = fs, shell = shell})

	local bootstrap_command
	local package_command
	for _, command in ipairs(commands) do
		if command:find("gen_sdk_package_pbzx.sh", 1, true) then
			bootstrap_command = command
		elseif command:find("package_macos_sdk.sh", 1, true) then
			package_command = command
		end
	end
	t:assert(bootstrap_command ~= nil)
	t:assert(bootstrap_command:find("build_xar && build_pbxz", 1, true) ~= nil)
	t:assert(package_command ~= nil)
	t:assert(package_command:find("/repo/build/downloads/Xcode_14.2.xip", 1, true) ~= nil)
	t:assert(package_command:find("/repo/build/deps/osxcross/tarballs/MacOSX13.1.sdk.tar.xz", 1, true) ~= nil)
	for _, command in ipairs(commands) do
		t:assert(command:find("mv build/deps/osxcross/MacOSX", 1, true) == nil)
	end
end

return test
