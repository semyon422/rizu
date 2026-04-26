---@class rizu.build.deps.spec.ActionSchema
local ActionSchema = {}

local requirements = {
	download = {"url", "dest"},
	extract = {"format", "archive", "dest"},
	extract_first_match = {"pattern", "format", "dest"},
	configure = {"dir"},
	compile_c = {"compiler", "output", "sources"},
	compile_cpp = {"compiler", "output", "sources"},
	make = {"dir"},
	cmake_configure = {"src_dir", "build_dir"},
	cmake_build = {"build_dir"},
	copy = {"src", "dst"},
	copy_exact = {"src", "dst"},
	move_first_match = {"pattern", "dst"},
	remove = {"path"},
	set_executable = {"path"},
	write_file = {"path", "content"},
	git_clone = {"url", "dest"},
	git_submodule = {"dir"},
	shell = {"command"},
	ensure_dir = {"path"},
	assert_exists = {"path"},
	assert_file = {"path"},
	assert_dir = {"path"},
	noop = {},
}

local shell_fallback_patterns = {
	"%|%|%s*cp%s",
	"if%s*%[.-%];%s*then%s*cp%s.-%s*else%s*cp%s",
	"if%s*%[",
}

---@param action rizu.build.deps.Action
---@param step rizu.build.deps.Step
function ActionSchema.validate(action, step)
	if type(action) ~= "table" then
		error("Action must be a table")
	end
	if not action.type then
		error("Action is missing required field 'type'")
	end
	local req = requirements[action.type]
	if not req then
		error("Unknown action type in schema: " .. tostring(action.type))
	end
	for _, key in ipairs(req) do
		if action[key] == nil then
			error(string.format("Action '%s' is missing required field '%s'", action.type, key))
		end
	end
	if action.type == "shell" then
		local command = tostring(action.command or "")
		for _, pattern in ipairs(shell_fallback_patterns) do
			if command:match(pattern) then
				error(string.format("Shell action '%s' contains forbidden fallback pattern '%s'", tostring(step.id), pattern))
			end
		end
	end
end

return ActionSchema
