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

function test.compile_cpp_builds_expected_command(t)
	local ctx, state = makeCtx()
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})

	local result = Executor.runStep(env, {
		id = "cpp",
		kind = "source-build",
		outputs = {"build/out/module.so"},
		requires = {},
		inputs = {},
		actions = {
			{
				type = "compile_cpp",
				dir = "build/deps/example",
				env = {CCACHE_DIR = "/tmp/cache", PATH = "/tool/bin:$PATH"},
				compiler = "g++",
				cflags = {"-shared", "-fPIC"},
				includes = {"include", "third_party/include"},
				sources = {"src/a.cpp", "src/b.cpp"},
				output = "build/out/module.so",
				lib_dirs = {"lib", "tree/lib"},
				libs = {"m", ":libluajit-5.1.dll.a"},
				ldflags = {"-Wl,-rpath,$ORIGIN"},
			},
		},
	})

	t:eq(result.ok, true)
	t:eq(#state.exec, 1)
	t:assert(result.command:find("CCACHE_DIR=", 1, true))
	t:assert(result.command:find("PATH=", 1, true))
	t:assert(result.command:find("cd \"build/deps/example\" &&", 1, true))
	t:assert(result.command:find("g++ -shared -fPIC", 1, true))
	t:assert(result.command:find("-I\"include\"", 1, true))
	t:assert(result.command:find("-I\"third_party/include\"", 1, true))
	t:assert(result.command:find("\"src/a.cpp\" \"src/b.cpp\"", 1, true))
	t:assert(result.command:find("-L\"lib\" -L\"tree/lib\"", 1, true))
	t:assert(result.command:find("-lm -l:libluajit-5.1.dll.a", 1, true))
	t:assert(result.command:find("-Wl,-rpath,$ORIGIN", 1, true))
end

return test
