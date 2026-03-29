local Util = require("rizu.build.deps.actions._util")

local M = {}

function M.install_name_tool_change(env, action)
	local tool = Util.resolve(env, action.tool)
	local target = Util.resolve(env, action.target)
	if action.mode == "id" then
		return Util.executeSafe(env, string.format("%q -id %q %q", tool, Util.resolve(env, action.to), target), action.stderr_hint)
	end
	return Util.executeSafe(env, string.format("%q -change %q %q %q", tool, Util.resolve(env, action.from), Util.resolve(env, action.to), target), action.stderr_hint)
end

return M
