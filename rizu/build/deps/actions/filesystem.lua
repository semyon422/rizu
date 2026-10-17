local Util = require("rizu.build.deps.actions._util")

---@type rizu.build.deps.Actions
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

---@param data string
---@param old_text string
---@param new_text string
---@param max_count integer?
---@return string
---@return integer
local function replacePlain(data, old_text, new_text, max_count)
	if old_text == "" then
		error("replace_text old_text must not be empty")
	end

	local parts = {}
	local pos = 1
	local count = 0

	while max_count == nil or count < max_count do
		local first, last = data:find(old_text, pos, true)
		if not first then
			break
		end
		table.insert(parts, data:sub(pos, first - 1))
		table.insert(parts, new_text)
		pos = last + 1
		count = count + 1
	end

	table.insert(parts, data:sub(pos))
	return table.concat(parts), count
end

function M.replace_text(env, action)
	local path = Util.resolve(env, action.path)
	local data, read_err = env.ctx.fs:read(path)
	if not data then
		error("Failed to read file for replace_text: " .. path .. ": " .. tostring(read_err))
	end

	for _, replacement in ipairs(action.replacements or {}) do
		local old_text = Util.resolve(env, replacement.old_text)
		local new_text = Util.resolve(env, replacement.new_text)
		local count
		data, count = replacePlain(data, old_text, new_text, replacement.count)
		if count == 0 and old_text:find("\n", 1, true) then
			local old_crlf = old_text:gsub("\n", "\r\n")
			local new_crlf = new_text:gsub("\n", "\r\n")
			data, count = replacePlain(data, old_crlf, new_crlf, replacement.count)
		end
		if count == 0 then
			error("replace_text did not find expected text in " .. path)
		end
	end

	local ok, write_err = env.ctx.fs:write(path, data)
	if not ok then
		error("Failed to write file for replace_text: " .. path .. ": " .. tostring(write_err))
	end
	return Util.resultOk(string.format("replace_text %s", path))
end

function M.noop(_env, _action)
	return Util.resultOk("<noop>")
end

return M
