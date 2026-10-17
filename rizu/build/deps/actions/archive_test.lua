local BuildEnv = require("rizu.build.deps.engine.BuildEnv")
local Executor = require("rizu.build.deps.engine.Executor")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

local function makeCtx()
	local state = {fs = FakeFilesystem(), exec = {}}
	state.fs:setWorkingDirectory("/repo")

	local shell = {}
	function shell:execute(cmd)
		table.insert(state.exec, cmd)
		return true
	end
	function shell:popen() return "" end

	return {fs = state.fs, shell = shell, downloader = {}}, state
end

---@param t testing.T
function test.extract_tar_xz_respects_custom_strip_components(t)
	local ctx, state = makeCtx()
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})

	Executor.runStep(env, {
		id = "sevenzip",
		kind = "archive",
		outputs = {"build/deps/7zsdk/C/Alloc.c"},
		inputs = {},
		actions = {
			{
				type = "extract",
				format = "tar.xz",
				archive = "${downloads_dir}/7z-src.tar.xz",
				dest = "${deps_dir}/7zsdk",
				strip_components = 0,
			},
		},
	})

	t:eq(#state.exec, 1)
	t:assert(state.exec[1]:find("tar --touch", 1, true) ~= nil)
	t:assert(state.exec[1]:find("--strip-components=0", 1, true) ~= nil)
end

---@param t testing.T
function test.extract_tar_gz_defaults_to_strip_one(t)
	local ctx, state = makeCtx()
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})

	Executor.runStep(env, {
		id = "source",
		kind = "archive",
		outputs = {"build/deps/source/configure"},
		inputs = {},
		actions = {
			{
				type = "extract",
				format = "tar.gz",
				archive = "${downloads_dir}/source.tar.gz",
				dest = "${deps_dir}/source",
			},
		},
	})

	t:eq(#state.exec, 1)
	t:assert(state.exec[1]:find("tar --touch", 1, true) ~= nil)
	t:assert(state.exec[1]:find("--strip-components=1", 1, true) ~= nil)
end

---@param t testing.T
function test.extract_cleans_existing_destination(t)
	local ctx, state = makeCtx()
	state.fs:createDirectory("build/deps/source")
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})

	Executor.runStep(env, {
		id = "source",
		kind = "archive",
		outputs = {"build/deps/source/configure"},
		inputs = {},
		actions = {
			{
				type = "extract",
				format = "tar.gz",
				archive = "${downloads_dir}/source.tar.gz",
				dest = "${deps_dir}/source",
			},
		},
	})

	t:eq(#state.exec, 2)
	t:assert(state.exec[1]:find('rm -rf "build/deps/source"', 1, true) ~= nil)
	t:assert(state.exec[2]:find("tar --touch", 1, true) ~= nil)
end

return test
