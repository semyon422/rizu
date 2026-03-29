local Util = require("rizu.build.deps.actions._util")

local M = {}

function M.assert_exists(env, action)
	local path = Util.resolve(env, action.path)
	if not env.ctx.fs:getInfo(path) then
		error(Util.resolve(env, action.message) or ("Missing required path: " .. path))
	end
	return Util.resultOk(string.format("assert_exists %s", path))
end

function M.assert_file(env, action)
	local path = Util.resolve(env, action.path)
	local info = env.ctx.fs:getInfo(path)
	if not info or info.type ~= "file" then
		error(Util.resolve(env, action.message) or ("Missing required file: " .. path))
	end
	return Util.resultOk(string.format("assert_file %s", path))
end

function M.assert_dir(env, action)
	local path = Util.resolve(env, action.path)
	local info = env.ctx.fs:getInfo(path)
	if not info or info.type ~= "directory" then
		error(Util.resolve(env, action.message) or ("Missing required directory: " .. path))
	end
	return Util.resultOk(string.format("assert_dir %s", path))
end

return M
