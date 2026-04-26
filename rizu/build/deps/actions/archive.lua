local Util = require("rizu.build.deps.actions._util")

local M = {}

local function stripComponents(action)
	if action.strip_components ~= nil then
		return action.strip_components
	end
	return 1
end

local function extractCommand(format, archive, dest, strip_components)
	if format == "tar.gz" then
		return string.format("tar --touch -xzf %q -C %q --strip-components=%d", archive, dest, strip_components)
	elseif format == "tar.xz" then
		return string.format("tar --touch -xf %q -C %q --strip-components=%d", archive, dest, strip_components)
	elseif format == "zip" then
		return string.format("unzip -o %q -d %q", archive, dest)
	elseif format == "zip_nested" then
		error("zip_nested should be handled by extract()")
	elseif format == "7z" then
		return string.format("7z x -y %q -o%q", archive, dest)
	end
	error("Unsupported extract format: " .. tostring(format))
end

function M.download(env, action)
	local dest = Util.resolve(env, action.dest)
	local info = env.ctx.fs:getInfo(dest)
	if info and info.size and info.size >= 1 then
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
		return Util.executeSafe(env, extractCommand(format, archive, dest, stripComponents(action)))
	elseif format == "tar.xz" then
		return Util.executeSafe(env, extractCommand(format, archive, dest, stripComponents(action)))
	elseif format == "zip" then
		return Util.executeSafe(env, extractCommand(format, archive, dest))
	elseif format == "zip_nested" then
		local tmp = Util.resolve(env, action.tmp or (dest .. "-tmp"))
		env.ctx.fs:createDirectory(tmp)
		Util.executeSafe(env, extractCommand("zip", archive, tmp))
		local result = Util.executeSafe(env, string.format("cp -r %s/*/* %s/", tmp, dest))
		env.ctx.fs:remove(tmp)
		return result
	elseif format == "7z" then
		return Util.executeSafe(env, extractCommand(format, archive, dest))
	end
	error("Unsupported extract format: " .. tostring(format))
end

function M.extract_first_match(env, action)
	local pattern = Util.resolve(env, action.pattern)
	local dest = Util.resolve(env, action.dest)
	local format = action.format
	if action.skip_if_exists and env.ctx.fs:getInfo(dest) then
		return Util.resultOk("<extract skipped>")
	end
	env.ctx.fs:createDirectory(dest)
	local cmd = string.format(
		"bash -lc 'shopt -s nullglob; matches=(%s); [ ${#matches[@]} -gt 0 ] || exit 1; %s'",
		pattern,
		extractCommand(format, "${matches[0]}", dest, stripComponents(action))
	)
	return Util.executeSafe(env, cmd)
end

return M
