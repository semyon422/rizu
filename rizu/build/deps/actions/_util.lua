local BuildEnv = require("rizu.build.deps.engine.BuildEnv")

local Util = {}

---@param env rizu.build.deps.Env
---@param value any
---@return any
function Util.resolve(env, value)
	if type(value) == "table" then
		local out = {}
		for k, v in pairs(value) do
			out[k] = Util.resolve(env, v)
		end
		return out
	end
	return BuildEnv.interpolate(env, value)
end

---@param command? string
---@return {ok: boolean, exit_code: integer, command: string, stderr_hint: string|nil}
function Util.resultOk(command)
	return {ok = true, exit_code = 0, command = command or "<noop>", stderr_hint = nil}
end

---@param env rizu.build.deps.Env
---@param cmd string
---@param stderr_hint? string
---@return {ok: boolean, exit_code: integer, command: string, stderr_hint: string|nil}
function Util.executeSafe(env, cmd, stderr_hint)
	local ok, err = pcall(function()
		env.ctx.shell:execute(cmd)
	end)
	local result = {
		ok = ok,
		exit_code = ok and 0 or 1,
		command = cmd,
		stderr_hint = ok and nil or (stderr_hint or tostring(err)),
	}
	if not ok then
		error(result.stderr_hint, 0)
	end
	return result
end

return Util
