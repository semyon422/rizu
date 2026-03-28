local Templates = {}

function Templates.bashInDir(dir, command)
	return "bash -lc 'cd " .. dir .. " && " .. command .. "'"
end

return Templates
