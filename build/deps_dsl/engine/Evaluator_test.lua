local Context = require("build.deps_dsl.engine.Context")
local Evaluator = require("build.deps_dsl.engine.Evaluator")

local test = {}

local function makeCtx()
	local state = {info = {}}
	local fs = {}
	function fs:getInfo(path) return state.info[path] end
	function fs:createDirectory(path)
		state.info[path] = state.info[path] or {type = "directory", modtime = 1}
	end
	function fs:remove(path) state.info[path] = nil end

	local shell = {}
	function shell:execute() return true end
	function shell:popen(cmd)
		if cmd == "pwd" then return "/repo\n" end
		return ""
	end

	local downloader = {}
	function downloader:download(url, dest)
		state.info[dest] = {type = "file", size = 100, modtime = 1}
	end

	return {fs = fs, shell = shell, downloader = downloader}, state
end

function test.evaluate_outputs_and_aggregate(t)
	local ctx, state = makeCtx()
	local env = Context.new(ctx, "linux", {initialize_dirs = false})
	local spec = {
		target = "linux",
		steps = {
			{id = "a", kind = "archive", status_label = "A", outputs = {"${deps_dir}/a"}, requires = {}, actions = {}},
			{id = "b", kind = "archive", status_label = "B", outputs = {"${deps_dir}/b"}, requires = {}, actions = {}},
		},
		outputs = {"${deps_dir}/a", "${deps_dir}/b"},
	}

	state.info["build/deps/a"] = {type = "directory", modtime = 1}
	local eval = Evaluator.evaluate(env, spec)
	t:eq(eval.aggregate, "MISSING")
	t:eq(eval.steps[1].state, "OK")
	t:eq(eval.steps[2].state, "MISSING")

	state.info["build/deps/b"] = {type = "directory", modtime = 1}
	t:eq(Evaluator.isUpToDate(env, spec), true)
end

function test.render_status_rows_includes_pipeline_row(t)
	local rows = Evaluator.renderStatusRows({
		target = "linux",
		steps = {
			{label = "one", state = "OK"},
		},
		aggregate = "OK",
	})
	t:eq(rows[#rows].name, "Pipeline (linux)")
	t:eq(rows[#rows].value, "OK")
end

return test
