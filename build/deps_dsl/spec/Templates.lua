local Templates = {}

function Templates.ifMissing(path, command)
	return "if [ ! -f " .. path .. " ]; then " .. command .. "; fi"
end

function Templates.ifAnyMissing(paths, command)
	local checks = {}
	for _, p in ipairs(paths) do
		table.insert(checks, "[ ! -f " .. p .. " ]")
	end
	return "if " .. table.concat(checks, " || ") .. "; then " .. command .. "; fi"
end

function Templates.bashInDir(dir, command)
	return "bash -lc 'cd " .. dir .. " && " .. command .. "'"
end

function Templates.pickLibDir(var_name, preferred, fallback)
	return var_name .. "=\"" .. preferred .. "\"; [ -f " .. preferred .. "/" .. "libssl.so ] || [ -f " .. preferred .. "/" .. "libssl.dylib ] || " .. var_name .. "=\"" .. fallback .. "\""
end

return Templates
