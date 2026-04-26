local BuildEnv = require("rizu.build.deps.engine.BuildEnv")
local StepState = require("rizu.build.deps.engine.StepState")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

local function makeCtx()
	local fs = FakeFilesystem()
	fs:setWorkingDirectory("/repo")

	local shell = {}
	function shell:execute() return true end
	function shell:popen() return "" end

	return {
		fs = fs,
		shell = shell,
		downloader = {},
	}
end

local function writePath(fs, path, time)
	fs:setTime(time)
	local parent = path:match("(.+)/[^/]+$")
	if parent then
		fs:createDirectory(parent)
	end
	fs:write(path, "x")
end

function test.outputs_state_and_skip_share_freshness_rules(t)
	local ctx = makeCtx()
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})
	local step = {
		id = "artifact",
		kind = "source-build",
		outputs = {"build/artifacts/linux/lib7z.so"},
		requires = {"build/deps/7zsdk/C/7z.h"},
		inputs = {"aqua/7z.c"},
		actions = {},
	}

	t:eq(StepState.hasAllRequired(env, step), false)

	writePath(ctx.fs, "build/deps/7zsdk/C/7z.h", 1)
	writePath(ctx.fs, "build/artifacts/linux/lib7z.so", 1)
	writePath(ctx.fs, "aqua/7z.c", 2)

	t:eq(StepState.hasAllRequired(env, step), true)
	t:eq(StepState.shouldSkip(env, step), false)
	local state = StepState.outputState(env, step)
	t:eq(state, "OUTDATED")

	writePath(ctx.fs, "build/artifacts/linux/lib7z.so", 3)

	t:eq(StepState.shouldSkip(env, step), true)
	state = StepState.outputState(env, step)
	t:eq(state, "OK")
end

return test
