local Context = require("build.deps_dsl.engine.Context")
local Executor = require("build.deps_dsl.engine.Executor")

local test = {}

local function makeCtx()
	local state = {info = {}, exec = {}, downloads = {}}
	local fs = {}
	function fs:getInfo(path) return state.info[path] end
	function fs:createDirectory(path) state.info[path] = state.info[path] or {type = "directory"} end
	function fs:remove(path) state.info[path] = nil end

	local shell = {}
	function shell:execute(cmd)
		table.insert(state.exec, cmd)
		return true
	end
	function shell:popen(cmd)
		if cmd == "pwd" then return "/repo\n" end
		return ""
	end

	local downloader = {}
	function downloader:download(url, dest)
		table.insert(state.downloads, {url = url, dest = dest})
		state.info[dest] = {type = "file", size = 100}
	end

	return {fs = fs, shell = shell, downloader = downloader}, state
end

function test.run_step_returns_structured_result(t)
	local ctx, state = makeCtx()
	local env = Context.new(ctx, "linux")
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
	t:assert(state.exec[1]:find("tar %-xzf"))
end

function test.skip_if_exists_all_skips_step_without_outputs(t)
	local ctx, state = makeCtx()
	state.info["build/deps/exists"] = {type = "directory"}
	local env = Context.new(ctx, "linux", {initialize_dirs = false})
	local result = Executor.runStep(env, {
		id = "skip",
		kind = "archive",
		skip_if_exists_all = {"build/deps/exists"},
		actions = {
			{type = "shell", command = "echo should-not-run"},
		},
	})
	t:eq(result.command, "<skipped>")
	t:eq(#state.exec, 0)
end

function test.outputs_take_precedence_over_skip_if_exists_all(t)
	local ctx, state = makeCtx()
	state.info["build/deps/exists"] = {type = "directory"}
	local env = Context.new(ctx, "linux", {initialize_dirs = false})
	local result = Executor.runStep(env, {
		id = "do-not-skip",
		kind = "archive",
		skip_if_exists_all = {"build/deps/exists"},
		outputs = {"build/deps/missing-output"},
		actions = {
			{type = "shell", command = "echo should-run", stderr_hint = "should run"},
		},
	})
	t:eq(result.command, "echo should-run")
	t:eq(#state.exec, 1)
end

function test.typed_actions_run_with_structured_result(t)
	local ctx, state = makeCtx()
	state.info["a"] = {type = "file", size = 1}
	state.info["dir"] = {type = "directory"}
	local env = Context.new(ctx, "linux", {initialize_dirs = false})
	local result = Executor.runStep(env, {
		id = "typed",
		kind = "archive",
		actions = {
			{type = "assert_file", path = "a"},
			{type = "assert_dir", path = "dir"},
			{type = "copy_exact", src = "a", dst = "b", stderr_hint = "copy_exact failed"},
			{type = "set_executable", path = "b", stderr_hint = "chmod failed"},
			{type = "toolchain_select", pattern = "/tmp/*", out_file = "/tmp/tc.txt", stderr_hint = "toolchain failed"},
			{type = "noop"},
		},
	})
	t:eq(result.ok, true)
	t:eq(result.step_id, "typed")
	t:assert(#state.exec >= 3)
end

function test.copy_exact_fails_when_source_missing(t)
	local ctx = makeCtx()
	local env = Context.new(ctx, "linux", {initialize_dirs = false})
	local ok, err = pcall(function()
		Executor.runStep(env, {
			id = "copy_fail",
			kind = "archive",
			actions = {
				{type = "copy_exact", src = "missing.file", dst = "dst.file", stderr_hint = "copy failed"},
			},
		})
	end)
	t:eq(ok, false)
	t:assert(tostring(err):find("Missing source for copy_exact"))
end

return test
