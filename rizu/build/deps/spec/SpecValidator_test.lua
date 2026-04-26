local SpecValidator = require("rizu.build.deps.spec.SpecValidator")

local test = {}

local function validStep(id)
	return {
		id = id,
		kind = "archive",
		actions = {{type = "noop"}},
		outputs = {},
		requires = {},
		inputs = {},
	}
end

local function expectErrorContains(t, fn, text)
	local ok, err = pcall(fn)
	t:eq(ok, false)
	t:assert(tostring(err):find(text, 1, true) ~= nil, tostring(err))
end

---@param t testing.T
function test.rejects_duplicate_step_ids(t)
	expectErrorContains(t, function()
		SpecValidator.validate({
			steps = {validStep("a"), validStep("a")},
			outputs = {},
		})
	end, "Duplicate step id")
end

---@param t testing.T
function test.rejects_unsupported_step_kind(t)
	local step = validStep("a")
	step.kind = "unknown-kind"

	expectErrorContains(t, function()
		SpecValidator.validate({
			steps = {step},
			outputs = {},
		})
	end, "unsupported kind 'unknown-kind'")
end

---@param t testing.T
function test.requires_normalized_step_tables(t)
	expectErrorContains(t, function()
		SpecValidator.validate({
			steps = {
				{
					id = "a",
					kind = "archive",
					actions = {{type = "noop"}},
					outputs = {},
				},
			},
			outputs = {},
		})
	end, "must define requires table")
end

return test
