local SpecNormalizer = require("rizu.build.deps.spec.SpecNormalizer")

local test = {}

---@param t testing.T
function test.fills_step_defaults_and_aggregates_outputs(t)
	local spec = {
		steps = {
			{
				id = "download",
				kind = "archive",
				actions = {
					{type = "download", url = "https://example.invalid/a.tar.gz", dest = "${downloads_dir}/a.tar.gz"},
				},
			},
			{
				id = "compile",
				kind = "source-build",
				actions = {
					{type = "compile_c", compiler = "cc", dir = "build/obj", sources = {"a.c"}, output = "libnative.so"},
				},
			},
			{
				id = "explicit",
				kind = "source-build",
				outputs = {"bin/manual.so"},
				actions = {
					{type = "noop"},
				},
			},
		},
	}

	SpecNormalizer.normalize(spec)

	t:tdeq(spec.steps[1].outputs, {"${downloads_dir}/a.tar.gz"})
	t:tdeq(spec.steps[1].inputs, {})
	t:eq(spec.steps[1].status_label, "download")
	t:tdeq(spec.steps[2].outputs, {"build/obj/libnative.so"})
end

return test
