local BuildEnv = require("rizu.build.deps.engine.BuildEnv")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

local function makeCtx(pwd)
	local fs = FakeFilesystem()
	fs:setWorkingDirectory(pwd or "/repo")

	local shell = {}
	function shell:execute() return true end
	function shell:popen() return "" end

	return {
		fs = fs,
		shell = shell,
		downloader = {},
	}
end

function test.uses_filesystem_working_directory_for_root_abs(t)
	local env = BuildEnv.new(makeCtx("/repo"), "linux", {initialize_dirs = false})
	t:eq(env.root_abs, "/repo")
end

return test
