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

return Templates
