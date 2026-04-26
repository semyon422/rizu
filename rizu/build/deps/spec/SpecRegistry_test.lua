local SpecRegistry = require("rizu.build.deps.spec.SpecRegistry")
local deps = require("rizu.build.deps.Manifest")

local test = {}

---@param t testing.T
function test.builds_specs_for_supported_targets(t)
	for _, target in ipairs({"linux", "windows", "macos"}) do
		local spec = SpecRegistry.build(target, deps)
		t:eq(spec.target, target)
		t:assert(type(spec.steps) == "table")
		t:assert(#spec.steps > 0)
	end
end

---@param t testing.T
function test.rejects_unknown_target(t)
	local ok, err = pcall(function()
		SpecRegistry.build("plan9", deps)
	end)
	t:eq(ok, false)
	t:assert(tostring(err):find("No DSL spec builder for target: plan9", 1, true) ~= nil, tostring(err))
end

return test
