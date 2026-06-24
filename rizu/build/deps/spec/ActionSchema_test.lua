local ActionSchema = require("rizu.build.deps.spec.ActionSchema")

local test = {}

local function expectErrorContains(t, fn, text)
	local ok, err = pcall(fn)
	t:eq(ok, false)
	t:assert(tostring(err):find(text, 1, true) ~= nil, tostring(err))
end

---@param t testing.T
function test.download_action_requires_url(t)
	expectErrorContains(t, function()
		ActionSchema.validate({type = "download", dest = "x"}, {id = "download"})
	end, "missing required field 'url'")
end

---@param t testing.T
function test.shell_action_without_stderr_hint_is_valid(t)
	local ok = pcall(function()
		ActionSchema.validate({type = "shell", command = "echo hi"}, {id = "shell"})
	end)
	t:eq(ok, true)
end

---@param t testing.T
function test.shell_action_rejects_fallback_patterns(t)
	expectErrorContains(t, function()
		ActionSchema.validate({
			type = "shell",
			command = "if [ -f /x/lib/libssl.so ]; then cp /x/lib/libssl.so y; else cp /x/lib64/libssl.so y; fi",
		}, {id = "shell"})
	end, "forbidden fallback pattern")
end

---@param t testing.T
function test.extract_action_requires_integer_strip_components(t)
	expectErrorContains(t, function()
		ActionSchema.validate({
			type = "extract",
			format = "tar.xz",
			archive = "archive.tar.xz",
			dest = "dst",
			strip_components = -1,
		}, {id = "extract"})
	end, "strip_components")
end

---@param t testing.T
function test.replace_text_action_requires_replacements(t)
	expectErrorContains(t, function()
		ActionSchema.validate({
			type = "replace_text",
			path = "file.c",
			replacements = {},
		}, {id = "replace_text"})
	end, "non-empty array")
end

---@param t testing.T
function test.replace_text_action_requires_text_fields(t)
	expectErrorContains(t, function()
		ActionSchema.validate({
			type = "replace_text",
			path = "file.c",
			replacements = {
				{old_text = "a"},
			},
		}, {id = "replace_text"})
	end, "new_text")
end

return test
