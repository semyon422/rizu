local BuildEnv = require("rizu.build.deps.engine.BuildEnv")

---@class rizu.build.deps.actions.Util
local Util = {}

---@generic T
---@param env rizu.build.deps.Env
---@param value T
---@return T
function Util.resolve(env, value)
	if type(value) == "table" then
		---@type {[any]: any}
		local out = {}
		---@diagnostic disable-next-line: no-unknown -- LuaLS 3.19 cannot infer generic-for values for this recursively generic table.
		for k, v in pairs(value) do
			out[k] = Util.resolve(env, v)
		end
		return out
	end
	return BuildEnv.interpolate(env, value)
end

---@param command string?
---@return rizu.build.deps.RunResult
function Util.resultOk(command)
	return {ok = true, exit_code = 0, command = command or "<noop>", stderr_hint = nil}
end

---@param env rizu.build.deps.Env
---@param cmd string
---@return rizu.build.deps.RunResult
function Util.executeSafe(env, cmd)
	local ok, err = pcall(function()
		env.ctx.shell:execute(cmd)
	end)
	local result = {
		ok = ok,
		exit_code = ok and 0 or 1,
		command = cmd,
		stderr_hint = ok and nil or tostring(err),
	}
	if not ok then
		error(result.stderr_hint, 0)
	end
	return result
end

return Util
