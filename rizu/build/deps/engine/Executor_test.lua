local BuildEnv = require("rizu.build.deps.engine.BuildEnv")
local Executor = require("rizu.build.deps.engine.Executor")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

local function makeCtx()
	local state = {fs = FakeFilesystem(), exec = {}, downloads = {}}
	state.fs:setWorkingDirectory("/repo")

	local shell = {}
	function shell:execute(cmd)
		table.insert(state.exec, cmd)
		return true
	end
	function shell:popen() return "" end

	local downloader = {}
	function downloader:download(url, dest)
		table.insert(state.downloads, {url = url, dest = dest})
		local parent = dest:match("(.+)/[^/]+$")
		if parent then
			state.fs:createDirectory(parent)
		end
		state.fs:write(dest, string.rep("x", 100))
	end

	return {fs = state.fs, shell = shell, downloader = downloader}, state
end

function test.run_step_returns_structured_result(t)
	local ctx, state = makeCtx()
	local env = BuildEnv.new(ctx, "linux")
	local result = Executor.runStep(env, {
		id = "demo",
		kind = "archive",
		actions = {
			{type = "download", url = "https://example.invalid/a.tar.gz", dest = "${downloads_dir}/a.tar.gz"},
			{type = "extract", format = "tar.gz", archive = "${downloads_dir}/a.tar.gz", dest = "${deps_dir}/a", skip_if_exists = true},
		},
	})
	t:eq(type(result), "table")
	t:eq(result.ok, true)
	t:eq(result.step_id, "demo")
	t:assert(#state.downloads == 1)
	t:assert(#state.exec >= 1)
	t:assert(state.exec[1]:find("tar %-%-touch %-xzf"))
end

function test.steps_without_outputs_do_not_skip(t)
	local ctx, state = makeCtx()
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})
	local step = {
		id = "no-output",
		kind = "archive",
		actions = {
			{type = "shell", command = "echo should-run"},
		},
	}
	local result = Executor.runStep(env, step)
	t:eq(result.command, "echo should-run")
	t:eq(#state.exec, 1)
end

function test.outputs_with_newer_inputs_do_not_skip_step(t)
	local ctx, state = makeCtx()
	state.fs:setTime(1)
	state.fs:createDirectory("build/artifacts/linux")
	state.fs:write("build/artifacts/linux/lib7z.so", "x")
	state.fs:setTime(2)
	state.fs:write("aqua/7z.c", "x")
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})
	local result = Executor.runStep(env, {
		id = "artifact",
		kind = "source-build",
		outputs = {"build/artifacts/linux/lib7z.so"},
		inputs = {"aqua/7z.c"},
		actions = {
			{type = "shell", command = "echo rebuild"},
		},
	})
	t:eq(result.command, "echo rebuild")
	t:eq(#state.exec, 1)
end

function test.typed_actions_run_with_structured_result(t)
	local ctx, state = makeCtx()
	state.fs:write("a", "x")
	state.fs:createDirectory("dir")
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})
	local result = Executor.runStep(env, {
		id = "typed",
		kind = "archive",
		actions = {
			{type = "assert_file", path = "a"},
			{type = "assert_dir", path = "dir"},
			{type = "copy_exact", src = "a", dst = "b"},
			{type = "set_executable", path = "b"},
			{type = "noop"},
		},
	})
	t:eq(result.ok, true)
	t:eq(result.step_id, "typed")
	t:assert(#state.exec >= 2)
end

function test.extract_first_match_and_recursive_remove_actions_run(t)
	local ctx, state = makeCtx()
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})
	local result = Executor.runStep(env, {
		id = "extract_match",
		kind = "archive",
		actions = {
			{type = "extract_first_match", pattern = '"/tmp"/love-*.zip', format = "zip", dest = "/tmp/out"},
			{type = "remove", path = "/tmp/out", recursive = true},
		},
	})
	t:eq(result.ok, true)
	t:assert(#state.exec >= 2)
	t:assert(state.exec[1]:find("matches=", 1, true))
	t:assert(state.exec[2]:find("rm %-rf", 1))
end

function test.move_first_match_action_runs(t)
	local ctx, state = makeCtx()
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})
	local result = Executor.runStep(env, {
		id = "move_match",
		kind = "archive",
		actions = {
			{type = "move_first_match", pattern = '"/tmp"/love-*.AppImage', dst = "/tmp/love.AppImage"},
		},
	})
	t:eq(result.ok, true)
	t:eq(#state.exec, 1)
	t:assert(state.exec[1]:find("mv %-f", 1))
	t:assert(state.exec[1]:find("matches=", 1, true))
end

function test.shell_action_supports_dir(t)
	local ctx, state = makeCtx()
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})
	local result = Executor.runStep(env, {
		id = "shell_with_dir",
		kind = "archive",
		actions = {
			{type = "shell", dir = "/tmp/work", command = "echo hi"},
		},
	})
	t:eq(result.ok, true)
	t:assert(result.command:find("cd \"/tmp/work\" && echo hi", 1, true))
	t:eq(#state.exec, 1)
end

function test.copy_exact_fails_when_source_missing(t)
	local ctx = makeCtx()
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})
	local ok, err = pcall(function()
		Executor.runStep(env, {
			id = "copy_fail",
			kind = "archive",
			actions = {
				{type = "copy_exact", src = "missing.file", dst = "dst.file"},
			},
		})
	end)
	t:eq(ok, false)
	t:assert(tostring(err):find("Missing source for copy_exact"))
end

function test.run_spec_runs_steps_with_missing_inputs(t)
	local ctx, state = makeCtx()
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})

	local results = Executor.runSpec(env, {
		target = "linux",
		steps = {
			{
				id = "first",
				kind = "archive",
				actions = {
					{type = "shell", command = "echo first"},
				},
			},
			{
				id = "second",
				kind = "archive",
				inputs = {"build/deps/required-file"},
				actions = {
					{type = "shell", command = "echo second"},
				},
			},
		},
	})

	t:eq(#results, 2)
	t:eq(results[1].command, "echo first")
	t:eq(results[2].command, "echo second")
	t:eq(#state.exec, 2)
end

return test
