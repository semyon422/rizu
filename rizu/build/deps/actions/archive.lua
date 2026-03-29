local Util = require("rizu.build.deps.actions._util")

local M = {}

function M.download(env, action)
	local dest = Util.resolve(env, action.dest)
	local info = env.ctx.fs:getInfo(dest)
	local min_size = action.min_size or 1
	if info and info.size and info.size >= min_size then
		return Util.resultOk("<download skipped>")
	end
	env.ctx.downloader:download(Util.resolve(env, action.url), dest)
	return Util.resultOk(string.format("download %s -> %s", tostring(Util.resolve(env, action.url)), dest))
end

function M.extract(env, action)
	local archive = Util.resolve(env, action.archive)
	local dest = Util.resolve(env, action.dest)
	local format = action.format
	if action.skip_if_exists and env.ctx.fs:getInfo(dest) then
		return Util.resultOk("<extract skipped>")
	end
	env.ctx.fs:createDirectory(dest)
	if format == "tar.gz" then
		return Util.executeSafe(env, string.format("tar -xzf %q -C %q --strip-components=1", archive, dest), action.stderr_hint)
	elseif format == "tar.xz" then
		return Util.executeSafe(env, string.format("tar -xf %q -C %q --strip-components=1", archive, dest), action.stderr_hint)
	elseif format == "zip" then
		return Util.executeSafe(env, string.format("unzip -o %q -d %q", archive, dest), action.stderr_hint)
	elseif format == "zip_nested" then
		local tmp = Util.resolve(env, action.tmp or (dest .. "-tmp"))
		env.ctx.fs:createDirectory(tmp)
		Util.executeSafe(env, string.format("unzip -o %q -d %q", archive, tmp), action.stderr_hint)
		local result = Util.executeSafe(env, string.format("cp -r %s/*/* %s/", tmp, dest), action.stderr_hint)
		env.ctx.fs:remove(tmp)
		return result
	elseif format == "7z" then
		return Util.executeSafe(env, string.format("7z x -y %q -o%q", archive, dest), action.stderr_hint)
	end
	error("Unsupported extract format: " .. tostring(format))
end

return M
