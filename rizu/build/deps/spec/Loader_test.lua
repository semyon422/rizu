local Loader = require("rizu.build.deps.spec.Loader")
local deps = require("rizu.build.deps.Manifest")

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

function test.shell_action_without_stderr_hint_is_valid(t)
	local spec = {
		steps = {
			{id = "s", kind = "archive", outputs = {}, requires = {}, actions = {{type = "shell", command = "echo hi"}}},
		},
		outputs = {},
	}
	local ok = pcall(function()
		Loader.validate(spec)
	end)
	t:eq(ok, true)
end

function test.shell_action_rejects_fallback_patterns(t)
	local spec = {
		steps = {
			{
				id = "s",
				kind = "archive",
				outputs = {},
				requires = {},
				actions = {{
					type = "shell",
					command = "if [ -f /x/lib/libssl.so ]; then cp /x/lib/libssl.so y; else cp /x/lib64/libssl.so y; fi",
				}},
			},
		},
		outputs = {},
	}
	local ok, err = pcall(function()
		Loader.validate(spec)
	end)
	t:eq(ok, false)
	t:assert(tostring(err):find("forbidden fallback pattern"))
end

return test
