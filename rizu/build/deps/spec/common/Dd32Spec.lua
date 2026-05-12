---@class rizu.build.deps.spec.common.Dd32Spec
local Dd32Spec = {}

local DD32_RELATIVE_PATH = "${deps_dir}/dd32.sh"
local DD32_ABSOLUTE_PATH = "${root_abs}/${deps_dir}/dd32.sh"
local DD32_CONTENT = "#!/bin/sh\ncat | head -c 32\n"

---@param actions rizu.build.deps.Action[]
function Dd32Spec.addSetup(actions)
	table.insert(actions, {type = "write_file", path = DD32_RELATIVE_PATH, content = DD32_CONTENT})
	table.insert(actions, {type = "set_executable", path = DD32_RELATIVE_PATH})
end

---@param env {[string]: string}
---@return {[string]: string}
function Dd32Spec.extendEnv(env)
	env.ac_cv_path_lt_DD = DD32_ABSOLUTE_PATH
	env.DD = DD32_ABSOLUTE_PATH
	return env
end

---@return {[string]: string}
function Dd32Spec.env()
	return Dd32Spec.extendEnv({})
end

return Dd32Spec
