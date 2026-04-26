local Util = require("rizu.build.deps.actions._util")

local M = {}

local function appendAll(dst, src)
	for _, item in ipairs(src or {}) do
		table.insert(dst, item)
	end
end

local function toEnvPrefix(env_map)
	if not env_map then
		return ""
	end
	local parts = {}
	for k, v in pairs(env_map) do
		table.insert(parts, string.format("%s=%q", tostring(k), tostring(v)))
	end
	table.sort(parts)
	return table.concat(parts, " ") .. " "
end

local function quotePath(path)
	return string.format("%q", tostring(path))
end

local function buildCompileCommand(env, action)
	local compiler = Util.resolve(env, action.compiler)
	local output = Util.resolve(env, action.output)
	local sources = Util.resolve(env, action.sources or {})
	local cflags = Util.resolve(env, action.cflags or {})
	local includes = Util.resolve(env, action.includes or {})
	local lib_dirs = Util.resolve(env, action.lib_dirs or {})
	local libs = Util.resolve(env, action.libs or {})
	local ldflags = Util.resolve(env, action.ldflags or {})
	local extra_args = Util.resolve(env, action.args or {})

	local parts = {compiler}
	appendAll(parts, cflags)
	for _, inc in ipairs(includes) do
		table.insert(parts, "-I" .. quotePath(inc))
	end
	for _, src in ipairs(sources) do
		table.insert(parts, quotePath(src))
	end
	table.insert(parts, "-o")
	table.insert(parts, quotePath(output))
	for _, lib_dir in ipairs(lib_dirs) do
		table.insert(parts, "-L" .. quotePath(lib_dir))
	end
	for _, lib in ipairs(libs) do
		table.insert(parts, "-l" .. tostring(lib))
	end
	appendAll(parts, ldflags)
	appendAll(parts, extra_args)

	local cmd = table.concat(parts, " ")
	cmd = toEnvPrefix(Util.resolve(env, action.env)) .. cmd

	local dir = action.dir and Util.resolve(env, action.dir)
	if dir then
		cmd = string.format("bash -lc 'cd %q && %s'", dir, cmd)
	end

	return cmd
end

local function runCompile(env, action)
	return Util.executeSafe(env, buildCompileCommand(env, action))
end

function M.compile_c(env, action)
	return runCompile(env, action)
end

function M.compile_cpp(env, action)
	return runCompile(env, action)
end

return M
