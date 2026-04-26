local DependencySpec = require("rizu.build.deps.spec.DependencySpec")
local deps = require("rizu.build.deps.Manifest")

local test = {}

---@param t testing.T
function test.loads_normalized_valid_specs_for_all_targets(t)
	for _, target in ipairs({"linux", "windows", "macos"}) do
		local spec = DependencySpec.load(target, deps)
		t:eq(spec.target, target)
		t:assert(#spec.steps > 0)
		t:assert(#spec.outputs > 0)

		for _, step in ipairs(spec.steps) do
			t:assert(type(step.outputs) == "table")
			t:assert(type(step.requires) == "table")
			t:assert(type(step.inputs) == "table")
			t:assert(type(step.status_label) == "string")
		end
	end
end

return test
