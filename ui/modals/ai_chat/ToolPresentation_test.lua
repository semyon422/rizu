local json = require("web.json")
local ToolPresentation = require("ui.modals.ai_chat.ToolPresentation")

local test = {}

---@param t testing.T
function test.formats_multiline_arguments_without_json_escapes(t)
	local arguments = json.encode({
		code = "local response = request(\"https://example.com\")\nreturn response",
	})
	t:eq(
		ToolPresentation.formatArguments(arguments),
		"code:\n  local response = request(\"https://example.com\")\n  return response"
	)
end

---@param t testing.T
function test.formats_lua_eval_values_without_dump_escapes_or_addresses(t)
	local content = json.encode({
		ok = true,
		output = "",
		values = {
			[=[<table: 0x123abc> {
  body = "<html>\n<meta charset=\"utf-8\">",
}]=],
		},
	})
	local formatted = ToolPresentation.formatResult("lua_eval", content)
	t:eq(formatted, [=[{
  body = "<html>
<meta charset="utf-8">",
}]=])
	t:eq(formatted:find("\\n", 1, true), nil)
	t:eq(formatted:find('\\"', 1, true), nil)
	t:eq(formatted:find("0x123abc", 1, true), nil)
end

---@param t testing.T
function test.formats_generic_json_as_readable_fields(t)
	local content = json.encode({
		ok = true,
		items = {
			{name = "first", active = true},
			{name = "second", active = false},
		},
	})
	t:eq(ToolPresentation.formatResult("inspect_runtime", content), [[items:
  - active: true
    name: first
  - active: false
    name: second
ok: true]])
end

---@param t testing.T
function test.preserves_plain_text(t)
	t:eq(ToolPresentation.formatResult("read_file", "line 1\nline 2"), "line 1\nline 2")
	t:eq(ToolPresentation.formatArguments("{broken"), "{broken")
end

return test
