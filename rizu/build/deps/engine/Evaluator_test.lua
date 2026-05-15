local BuildEnv = require("rizu.build.deps.engine.BuildEnv")
local Evaluator = require("rizu.build.deps.engine.Evaluator")
local FakeFilesystem = require("fs.FakeFilesystem")

local test = {}

local function makeCtx()
	local state = {fs = FakeFilesystem()}
	state.fs:setWorkingDirectory("/repo")

	local shell = {}
	function shell:execute() return true end
	function shell:popen() return "" end

	local downloader = {}
	function downloader:download(url, dest)
		state.fs:setTime(1)
		local parent = dest:match("(.+)/[^/]+$")
		if parent then
			state.fs:createDirectory(parent)
		end
		state.fs:write(dest, string.rep("x", 100))
	end

	return {fs = state.fs, shell = shell, downloader = downloader}, state
end

function test.evaluate_outputs_and_aggregate(t)
	local ctx, state = makeCtx()
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})
	local spec = {
		target = "linux",
		steps = {
			{id = "a", kind = "archive", status_label = "A", outputs = {"${deps_dir}/a"}, actions = {}},
			{id = "b", kind = "archive", status_label = "B", outputs = {"${deps_dir}/b"}, actions = {}},
		},
		outputs = {"${deps_dir}/a", "${deps_dir}/b"},
	}

	state.fs:setTime(1)
	state.fs:createDirectory("build/deps/a")
	local eval = Evaluator.evaluate(env, spec)
	t:eq(eval.aggregate, "MISSING")
	t:eq(eval.steps[1].state, "OK")
	t:eq(eval.steps[2].state, "MISSING")

	state.fs:setTime(1)
	state.fs:createDirectory("build/deps/b")
	t:eq(Evaluator.isUpToDate(env, spec), true)
end

function test.render_status_rows_includes_build_target_row(t)
	local rows = Evaluator.renderStatusRows({
		target = "linux",
		steps = {
			{label = "one", state = "OK"},
		},
		aggregate = "OK",
	})
	t:eq(rows[#rows].name, "Build Target (linux)")
	t:eq(rows[#rows].value, "OK")
end

function test.run_result_failure_sets_failed_state(t)
	local ctx = makeCtx()
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})
	local spec = {
		target = "linux",
		steps = {
			{id = "a", kind = "archive", status_label = "A", outputs = {}, actions = {}},
		},
		outputs = {},
	}
	local eval = Evaluator.evaluate(env, spec, {
		{step_id = "a", ok = false, exit_code = 1, command = "x", stderr_hint = "boom"},
	})
	t:eq(eval.steps[1].state, "FAILED")
	t:eq(eval.aggregate, "FAILED")
end

function test.inputs_newer_than_outputs_mark_step_outdated(t)
	local ctx, state = makeCtx()
	local env = BuildEnv.new(ctx, "linux", {initialize_dirs = false})
	local spec = {
		target = "linux",
		steps = {
			{
				id = "native",
				kind = "source-build",
				status_label = "Native",
				outputs = {"build/artifacts/linux/lib7z.so"},
				inputs = {"aqua/7z.c"},
				actions = {},
			},
		},
		outputs = {"build/artifacts/linux/lib7z.so"},
	}

	state.fs:setTime(1)
	state.fs:createDirectory("build/artifacts/linux")
	state.fs:write("build/artifacts/linux/lib7z.so", "x")
	state.fs:setTime(2)
	state.fs:createDirectory("aqua")
	state.fs:write("aqua/7z.c", "x")

	local eval = Evaluator.evaluate(env, spec)
	t:eq(eval.steps[1].state, "OUTDATED")
	t:eq(eval.aggregate, "OUTDATED")
end

return test
