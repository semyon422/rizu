local Loader = require("build.deps_dsl.spec.Loader")
local deps = require("build.deps")

local test = {}

function test.load_specs_for_all_targets(t)
	local linux = Loader.load("linux", deps)
	t:assert(type(linux) == "table")
	t:assert(#linux.steps > 0)
	t:assert(#linux.outputs > 0)
	t:assert(type(linux.steps[1].outputs) == "table")
	t:assert(type(linux.steps[1].requires) == "table")

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
			{id = "a", kind = "archive", outputs = {}, requires = {}, actions = {{type = "download", dest = "x"}}},
			{id = "a", kind = "archive", actions = {{type = "shell", command = "true"}}},
		},
		outputs = {},
	}
	local ok, err = pcall(function()
		Loader.validate(bad)
	end)
	t:eq(ok, false)
	t:assert(
		tostring(err):find("missing required field 'url'")
		or tostring(err):find("Duplicate step id")
	)
end

function test.shell_action_gets_default_hint(t)
	local spec = {
		steps = {
			{id = "s", kind = "archive", outputs = {}, requires = {}, actions = {{type = "shell", command = "echo hi"}}},
		},
		outputs = {},
	}
	Loader.validate(spec)
	t:assert(spec.steps[1].actions[1].stderr_hint:find("Shell action failed"))
end

return test
