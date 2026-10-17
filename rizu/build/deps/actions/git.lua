local Util = require("rizu.build.deps.actions._util")

---@type rizu.build.deps.Actions
local M = {}

function M.git_clone(env, action)
	local dest = Util.resolve(env, action.dest)
	if env.ctx.fs:getInfo(dest) then
		return Util.resultOk("<git clone skipped>")
	end
	return Util.executeSafe(env, string.format("git clone %s %s", Util.resolve(env, action.url), dest))
end

function M.git_submodule(env, action)
	local dir = Util.resolve(env, action.dir)
	local marker = action.marker and Util.resolve(env, action.marker)
	if marker and env.ctx.fs:getInfo(marker) then
		return Util.resultOk("<git submodule skipped>")
	end
	return Util.executeSafe(env, string.format("git -C %s submodule update --init --recursive", dir))
end

return M
