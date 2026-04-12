local Util = require("rizu.build.deps.actions._util")

local M = {}

function M.copy(env, action)
	local src = Util.resolve(env, action.src)
	local dst = Util.resolve(env, action.dst)
	local flags = action.flags or "-f"
	return Util.executeSafe(env, string.format("cp %s %s %s", flags, src, dst))
end

function M.copy_exact(env, action)
	local src = Util.resolve(env, action.src)
	if not env.ctx.fs:getInfo(src) then
		error("Missing source for copy_exact: " .. src)
	end
	return M.copy(env, action)
end

function M.set_executable(env, action)
	local path = Util.resolve(env, action.path)
	return Util.executeSafe(env, string.format("chmod +x %q", path))
end

function M.toolchain_select(env, action)
	local pattern = Util.resolve(env, action.pattern)
	local out_file = Util.resolve(env, action.out_file)
	local cmd = string.format("bash -lc 'ls %s 2>/dev/null | head -n1 > %q'", pattern, out_file)
	return Util.executeSafe(env, cmd)
end

function M.remove(env, action)
	local path = Util.resolve(env, action.path)
	local flags = action.recursive and "-rf" or "-f"
	return Util.executeSafe(env, string.format("rm %s %q", flags, path))
end

function M.move_first_match(env, action)
	local pattern = Util.resolve(env, action.pattern)
	local dst = Util.resolve(env, action.dst)
	local cmd = string.format(
		"bash -lc 'shopt -s nullglob; matches=(%s); [ ${#matches[@]} -gt 0 ] || exit 1; mv -f \"${matches[0]}\" %q'",
		pattern,
		dst
	)
	return Util.executeSafe(env, cmd)
end

function M.ensure_dir(env, action)
	env.ctx.fs:createDirectory(Util.resolve(env, action.path))
	return Util.resultOk(string.format("mkdir %s", Util.resolve(env, action.path)))
end

function M.write_file(env, action)
	local path = Util.resolve(env, action.path)
	local content = Util.resolve(env, action.content or "")
	local parent = path:match("(.+)/[^/]+$")
	if parent then
		env.ctx.fs:createDirectory(parent)
	end
	env.ctx.fs:write(path, content)
	return Util.resultOk(string.format("write_file %s", path))
end

return M
