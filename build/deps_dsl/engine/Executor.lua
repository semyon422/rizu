local Ctx = require("build.deps_dsl.engine.Context")
local Builder = require("build.Builder")

---@class build.deps_dsl.engine.Executor
local Executor = {}

---@param env build.deps_dsl.Env
---@param value any
---@return any
local function resolve(env, value)
	if type(value) == "table" then
		local out = {}
		for k, v in pairs(value) do
			out[k] = resolve(env, v)
		end
		return out
	end
	return Ctx.interpolate(env, value)
end

---@param step_id string
---@param command? string
---@return build.deps_dsl.RunResult
local function resultOk(step_id, command)
	return {ok = true, exit_code = 0, step_id = step_id, command = command or "<noop>", stderr_hint = nil}
end

local function executeSafe(env, step_id, cmd, stderr_hint)
	local ok, err = pcall(function()
		env.ctx.shell:execute(cmd)
	end)
	local result = {
		ok = ok,
		exit_code = ok and 0 or 1,
		step_id = step_id,
		command = cmd,
		stderr_hint = ok and nil or (stderr_hint or tostring(err)),
	}
	if not ok then
		error(string.format("Step '%s' failed: %s", step_id, result.stderr_hint), 0)
	end
	return result
end

local function download(env, step, action)
	local dest = resolve(env, action.dest)
	local info = env.ctx.fs:getInfo(dest)
	local min_size = action.min_size or 1
	if info and info.size and info.size >= min_size then
		return resultOk(step.id, "<download skipped>")
	end
	env.ctx.downloader:download(resolve(env, action.url), dest)
	return resultOk(step.id, string.format("download %s -> %s", tostring(resolve(env, action.url)), dest))
end

local function extract(env, step, action)
	local archive = resolve(env, action.archive)
	local dest = resolve(env, action.dest)
	local format = action.format
	if action.skip_if_exists and env.ctx.fs:getInfo(dest) then
		return resultOk(step.id, "<extract skipped>")
	end
	env.ctx.fs:createDirectory(dest)
	if format == "tar.gz" then
		return executeSafe(env, step.id, string.format("tar -xzf %q -C %q --strip-components=1", archive, dest), action.stderr_hint)
	elseif format == "tar.xz" then
		return executeSafe(env, step.id, string.format("tar -xf %q -C %q --strip-components=1", archive, dest), action.stderr_hint)
	elseif format == "zip" then
		return executeSafe(env, step.id, string.format("unzip -o %q -d %q", archive, dest), action.stderr_hint)
	elseif format == "zip_nested" then
		local tmp = resolve(env, action.tmp or (dest .. "-tmp"))
		env.ctx.fs:createDirectory(tmp)
		executeSafe(env, step.id, string.format("unzip -o %q -d %q", archive, tmp), action.stderr_hint)
		local r = executeSafe(env, step.id, string.format("cp -r %s/*/* %s/", tmp, dest), action.stderr_hint)
		env.ctx.fs:remove(tmp)
		return r
	elseif format == "7z" then
		return executeSafe(env, step.id, string.format("7z x -y %q -o%q", archive, dest), action.stderr_hint)
	else
		error("Unsupported extract format: " .. tostring(format))
	end
end

local function run_in_dir(env, step, action)
	local dir = resolve(env, action.dir)
	local cmd = resolve(env, action.command)
	return executeSafe(env, step.id, string.format("bash -lc 'cd %q && %s'", dir, cmd), action.stderr_hint)
end

local function make_action(env, step, action)
	local dir = resolve(env, action.dir)
	local args = resolve(env, action.args or "")
	return executeSafe(env, step.id, string.format("bash -lc 'cd %q && make %s'", dir, args), action.stderr_hint)
end

local function copy_action(env, step, action)
	local src = resolve(env, action.src)
	local dst = resolve(env, action.dst)
	local flags = action.flags or "-f"
	return executeSafe(env, step.id, string.format("cp %s %s %s", flags, src, dst), action.stderr_hint)
end

local function copy_exact(env, step, action)
	local src = resolve(env, action.src)
	if not env.ctx.fs:getInfo(src) then
		error(resolve(env, action.message) or ("Missing source for copy_exact: " .. src))
	end
	return copy_action(env, step, action)
end

local function set_executable(env, step, action)
	local path = resolve(env, action.path)
	return executeSafe(env, step.id, string.format("chmod +x %q", path), action.stderr_hint)
end

local function toolchain_select(env, step, action)
	local pattern = resolve(env, action.pattern)
	local out_file = resolve(env, action.out_file)
	local cmd = string.format("bash -lc 'ls %s 2>/dev/null | head -n1 > %q'", pattern, out_file)
	return executeSafe(env, step.id, cmd, action.stderr_hint)
end

local function remove_action(env, step, action)
	local path = resolve(env, action.path)
	return executeSafe(env, step.id, string.format("rm -f %q", path), action.stderr_hint)
end

local function git_clone(env, step, action)
	local dest = resolve(env, action.dest)
	if env.ctx.fs:getInfo(dest) then
		return resultOk(step.id, "<git clone skipped>")
	end
	return executeSafe(env, step.id, string.format("git clone %s %s", resolve(env, action.url), dest), action.stderr_hint)
end

local function git_submodule(env, step, action)
	local dir = resolve(env, action.dir)
	local marker = action.marker and resolve(env, action.marker)
	if marker and env.ctx.fs:getInfo(marker) then
		return resultOk(step.id, "<git submodule skipped>")
	end
	return executeSafe(env, step.id, string.format("git -C %s submodule update --init --recursive", dir), action.stderr_hint)
end

local function install_name_tool_change(env, step, action)
	local tool = resolve(env, action.tool)
	local target = resolve(env, action.target)
	if action.mode == "id" then
		return executeSafe(env, step.id, string.format("%q -id %q %q", tool, resolve(env, action.to), target), action.stderr_hint)
	end
	return executeSafe(env, step.id, string.format("%q -change %q %q %q", tool, resolve(env, action.from), resolve(env, action.to), target), action.stderr_hint)
end

local function shell_action(env, step, action)
	local cmd = resolve(env, action.command)
	local dir = action.dir and resolve(env, action.dir)
	if dir then
		cmd = string.format("bash -lc 'cd %q && %s'", dir, cmd)
	end
	return executeSafe(env, step.id, cmd, action.stderr_hint)
end

local function ensure_dir(env, step, action)
	env.ctx.fs:createDirectory(resolve(env, action.path))
	return resultOk(step.id, string.format("mkdir %s", resolve(env, action.path)))
end

local function assert_exists(env, step, action)
	local path = resolve(env, action.path)
	if not env.ctx.fs:getInfo(path) then
		error(resolve(env, action.message) or ("Missing required path: " .. path))
	end
	return resultOk(step.id, string.format("assert_exists %s", path))
end

local function assert_file(env, step, action)
	local path = resolve(env, action.path)
	local info = env.ctx.fs:getInfo(path)
	if not info or info.type ~= "file" then
		error(resolve(env, action.message) or ("Missing required file: " .. path))
	end
	return resultOk(step.id, string.format("assert_file %s", path))
end

local function assert_dir(env, step, action)
	local path = resolve(env, action.path)
	local info = env.ctx.fs:getInfo(path)
	if not info or info.type ~= "directory" then
		error(resolve(env, action.message) or ("Missing required directory: " .. path))
	end
	return resultOk(step.id, string.format("assert_dir %s", path))
end

local function build_modules(env, step)
	local builder = Builder(env.ctx, env.target)
	builder:run()
	return resultOk(step.id, "builder:run")
end

local function sync_binaries(env, step)
	local builder = Builder(env.ctx, env.target)
	builder:syncMissingToBin()
	return resultOk(step.id, "builder:syncMissingToBin")
end

local function noop(env, step)
	return resultOk(step.id, "<noop>")
end

local handlers = {
	download = download,
	extract = extract,
	run_in_dir = run_in_dir,
	configure = run_in_dir,
	make = make_action,
	copy = copy_action,
	copy_exact = copy_exact,
	set_executable = set_executable,
	toolchain_select = toolchain_select,
	remove = remove_action,
	git_clone = git_clone,
	git_submodule = git_submodule,
	install_name_tool_change = install_name_tool_change,
	shell = shell_action,
	ensure_dir = ensure_dir,
	assert_exists = assert_exists,
	assert_file = assert_file,
	assert_dir = assert_dir,
	build_modules = build_modules,
	sync_binaries = sync_binaries,
	noop = noop,
}

local function shouldSkip(env, step)
	if step.outputs and #step.outputs > 0 then
		for _, p in ipairs(step.outputs) do
			if not env.ctx.fs:getInfo(resolve(env, p)) then
				return false
			end
		end
		return true
	end
	local checks = step.skip_if_exists_all
	if checks and #checks > 0 then
		for _, p in ipairs(checks) do
			if not env.ctx.fs:getInfo(resolve(env, p)) then
				return false
			end
		end
		return true
	end
	return false
end

---@param env build.deps_dsl.Env
---@param step build.deps_dsl.Step
---@return build.deps_dsl.RunResult
function Executor.runStep(env, step)
	if shouldSkip(env, step) then
		return {ok = true, exit_code = 0, step_id = step.id, command = "<skipped>", stderr_hint = nil}
	end
	local last = {ok = true, exit_code = 0, step_id = step.id, command = "<noop>", stderr_hint = nil}
	for _, action in ipairs(step.actions or {}) do
		local handler = handlers[action.type]
		if not handler then
			error("Unknown action type: " .. tostring(action.type))
		end
		local result = handler(env, step, action)
		if result then
			last = result
		end
	end
	return last
end

---@param env build.deps_dsl.Env
---@param spec build.deps_dsl.Spec
---@return build.deps_dsl.RunResult[]
function Executor.runSpec(env, spec)
	local results = {}
	for _, step in ipairs(spec.steps or {}) do
		table.insert(results, Executor.runStep(env, step))
	end
	return results
end

return Executor
