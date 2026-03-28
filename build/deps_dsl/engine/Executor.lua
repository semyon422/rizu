local Ctx = require("build.deps_dsl.engine.Context")

local Executor = {}

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

local function executeSafe(env, step_id, cmd)
	local ok, err = pcall(function()
		env.ctx.shell:execute(cmd)
	end)
	local result = {
		ok = ok,
		exit_code = ok and 0 or 1,
		step_id = step_id,
		command = cmd,
		stderr_hint = ok and nil or tostring(err),
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
		return
	end
	env.ctx.downloader:download(resolve(env, action.url), dest)
end

local function extract(env, step, action)
	local archive = resolve(env, action.archive)
	local dest = resolve(env, action.dest)
	local format = action.format
	if action.skip_if_exists and env.ctx.fs:getInfo(dest) then
		return
	end
	env.ctx.fs:createDirectory(dest)
	if format == "tar.gz" then
		executeSafe(env, step.id, string.format("tar -xzf %q -C %q --strip-components=1", archive, dest))
	elseif format == "tar.xz" then
		executeSafe(env, step.id, string.format("tar -xf %q -C %q --strip-components=1", archive, dest))
	elseif format == "zip" then
		executeSafe(env, step.id, string.format("unzip -o %q -d %q", archive, dest))
	elseif format == "zip_nested" then
		local tmp = resolve(env, action.tmp or (dest .. "-tmp"))
		env.ctx.fs:createDirectory(tmp)
		executeSafe(env, step.id, string.format("unzip -o %q -d %q", archive, tmp))
		executeSafe(env, step.id, string.format("cp -r %s/*/* %s/", tmp, dest))
		env.ctx.fs:remove(tmp)
	elseif format == "7z" then
		executeSafe(env, step.id, string.format("7z x -y %q -o%q", archive, dest))
	else
		error("Unsupported extract format: " .. tostring(format))
	end
end

local function configure(env, step, action)
	local dir = resolve(env, action.dir)
	local cmd = resolve(env, action.command)
	executeSafe(env, step.id, string.format("bash -lc 'cd %q && %s'", dir, cmd))
end

local function make_action(env, step, action)
	local dir = resolve(env, action.dir)
	local args = resolve(env, action.args or "")
	executeSafe(env, step.id, string.format("bash -lc 'cd %q && make %s'", dir, args))
end

local function copy_action(env, step, action)
	local src = resolve(env, action.src)
	local dst = resolve(env, action.dst)
	local flags = action.flags or "-f"
	executeSafe(env, step.id, string.format("cp %s %s %s", flags, src, dst))
end

local function remove_action(env, step, action)
	local path = resolve(env, action.path)
	executeSafe(env, step.id, string.format("rm -f %q", path))
end

local function git_clone(env, step, action)
	local dest = resolve(env, action.dest)
	if env.ctx.fs:getInfo(dest) then
		return
	end
	executeSafe(env, step.id, string.format("git clone %s %s", resolve(env, action.url), dest))
end

local function git_submodule(env, step, action)
	local dir = resolve(env, action.dir)
	local marker = action.marker and resolve(env, action.marker)
	if marker and env.ctx.fs:getInfo(marker) then
		return
	end
	executeSafe(env, step.id, string.format("git -C %s submodule update --init --recursive", dir))
end

local function install_name_tool_change(env, step, action)
	local tool = resolve(env, action.tool)
	local target = resolve(env, action.target)
	if action.mode == "id" then
		executeSafe(env, step.id, string.format("%q -id %q %q", tool, resolve(env, action.to), target))
	else
		executeSafe(env, step.id, string.format("%q -change %q %q %q", tool, resolve(env, action.from), resolve(env, action.to), target))
	end
end

local function shell_action(env, step, action)
	executeSafe(env, step.id, resolve(env, action.command))
end

local function ensure_dir(env, _, action)
	env.ctx.fs:createDirectory(resolve(env, action.path))
end

local function assert_exists(env, _, action)
	local path = resolve(env, action.path)
	if not env.ctx.fs:getInfo(path) then
		error(resolve(env, action.message) or ("Missing required path: " .. path))
	end
end

local handlers = {
	download = download,
	extract = extract,
	configure = configure,
	make = make_action,
	copy = copy_action,
	remove = remove_action,
	git_clone = git_clone,
	git_submodule = git_submodule,
	install_name_tool_change = install_name_tool_change,
	shell = shell_action,
	ensure_dir = ensure_dir,
	assert_exists = assert_exists,
}

local function shouldSkip(env, step)
	local checks = step.skip_if_exists_all
	if not checks or #checks == 0 then
		return false
	end
	for _, p in ipairs(checks) do
		if not env.ctx.fs:getInfo(resolve(env, p)) then
			return false
		end
	end
	return true
end

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

function Executor.runSpec(env, spec)
	local results = {}
	for _, step in ipairs(spec.steps) do
		table.insert(results, Executor.runStep(env, step))
	end
	return results
end

return Executor
