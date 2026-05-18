local BuildConfig = require("rizu.build.BuildConfig")

---@class rizu.build.deps.spec.source.PrefixSpec
local PrefixSpec = {}

---@param target rizu.build.Target
---@param spec rizu.build.deps.Spec
---@param prefix string
function PrefixSpec.add(target, spec, prefix)
	local actions = {}
	if target == "macos" then
		table.insert(actions, {type = "assert_exists", path = BuildConfig.getOsxcrossToolchainBin()})
	end
	table.insert(actions, {type = "ensure_dir", path = "${deps_dir}/local"})
	table.insert(actions, {type = "ensure_dir", path = prefix})
	if target == "macos" then
		table.insert(actions, {type = "ensure_dir", path = prefix .. "/lib"})
		table.insert(actions, {type = "ensure_dir", path = prefix .. "/include"})
	end

	table.insert(spec.steps, {
		id = target .. "_prepare_prefix",
		kind = "source-build",
		actions = actions,
	})
end

return PrefixSpec
