local Util = require("rizu.build.deps.actions._util")

---@type rizu.build.deps.Actions
local M = {}

---@param args string|string[]|nil
---@return string
local function toArgString(args)
	if not args then
		return ""
	end
	if type(args) == "string" then
		return args
	end
	local out = {}
	for _, arg in ipairs(args) do
		table.insert(out, string.format("%q", tostring(arg)))
	end
	return table.concat(out, " ")
end

---@param env_map {[string]: string}?
---@return string
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

function M.make(env, action)
	local dir = Util.resolve(env, action.dir)
	local args = toArgString(Util.resolve(env, action.args))
	local env_prefix = toEnvPrefix(Util.resolve(env, action.env))
	local cmd = string.format("%smake%s%s", env_prefix, args ~= "" and " " or "", args)
	return Util.executeSafe(env, string.format("bash -lc 'cd %q && %s'", dir, cmd))
end

function M.configure(env, action)
	local dir = Util.resolve(env, action.dir)
	local script = Util.resolve(env, action.script or "./configure")
	local args = toArgString(Util.resolve(env, action.args))
	local env_prefix = toEnvPrefix(Util.resolve(env, action.env))
	local cmd = string.format("%s%s%s%s", env_prefix, script, args ~= "" and " " or "", args)
	return Util.executeSafe(env, string.format("bash -lc 'cd %q && %s'", dir, cmd))
end

function M.cmake_configure(env, action)
	local src_dir = Util.resolve(env, action.src_dir)
	local build_dir = Util.resolve(env, action.build_dir)
	local args = toArgString(Util.resolve(env, action.args))
	local env_prefix = toEnvPrefix(Util.resolve(env, action.env))
	local cmd = string.format("%scmake -S %q -B %q%s%s", env_prefix, src_dir, build_dir, args ~= "" and " " or "", args)
	return Util.executeSafe(env, cmd)
end

function M.cmake_build(env, action)
	local build_dir = Util.resolve(env, action.build_dir)
	local args = toArgString(Util.resolve(env, action.args))
	local env_prefix = toEnvPrefix(Util.resolve(env, action.env))
	local cmd = string.format("%scmake --build %q%s%s", env_prefix, build_dir, args ~= "" and " " or "", args)
	return Util.executeSafe(env, cmd)
end

function M.shell(env, action)
	local cmd = Util.resolve(env, action.command)
	local dir = action.dir and Util.resolve(env, action.dir)
	local env_prefix = toEnvPrefix(Util.resolve(env, action.env))
	cmd = env_prefix .. cmd
	if dir then
		cmd = string.format("bash -lc 'cd %q && %s'", dir, cmd)
	end
	return Util.executeSafe(env, cmd)
end

return M
