local Loader = require("build.deps_dsl.spec.Loader")
local deps = require("build.deps")

local test = {}

function test.load_specs_for_all_targets(t)
	local linux = Loader.load("linux", deps)
	t:assert(type(linux) == "table")
	t:assert(#linux.steps > 0)
	t:assert(#linux.required_paths > 0)
	t:assert(#linux.status_rows > 0)

	local windows = Loader.load("windows", deps)
	t:assert(#windows.steps > 0)

	local macos = Loader.load("macos", deps)
	t:assert(#macos.steps > 0)
end

function test.rejects_unknown_target(t)
	local ok, err = pcall(function()
		Loader.load("plan9", deps)
	end)
	t:eq(ok, false)
	t:assert(tostring(err):find("No DSL spec builder"))
end

function test.strict_validation_catches_bad_specs(t)
	local bad = {
		steps = {
			{id = "a", kind = "archive", actions = {{type = "download", dest = "x"}}},
			{id = "a", kind = "archive", actions = {{type = "shell", command = "true"}}},
		},
		required_paths = {},
		status_rows = {{name = "x", format = "unknown"}},
	}
	local ok, err = pcall(function()
		Loader.validate(bad)
	end)
	t:eq(ok, false)
	t:assert(
		tostring(err):find("missing required field 'url'")
		or tostring(err):find("Duplicate step id")
		or tostring(err):find("Unknown status format")
	)
end

return test
