local needle = require("ai.needle")
local json = require("web.json")

local model_path = arg[1] or os.getenv("NEEDLE_MODEL_PATH") or "resources/needle/needle-q8-stripped.bin"
local run_final = os.getenv("ROUTE_ONLY") ~= "1"

local routing_tools = {
	{name = "set_playback_rate", description = "rate speed playback music"},
	{name = "capture_screenshot", description = "screenshot capture image"},
	{name = "set_chart_search", description = "search filter charts songs"},
	{name = "select_random_chart", description = "random chart song select"},
	{name = "start_selected_chart", description = "play start chart autoplay"},
	{name = "set_column_layout", description = "columns layout mirror random"},
	{name = "set_play_option", description = "gameplay option enable disable"},
	{name = "open_panel", description = "open settings panel editor"},
}

local full_tools = {
	set_playback_rate = {
		name = "set_playback_rate",
		description = "Set the music playback rate.",
		parameters = {rate = {type = "number", description = "Playback rate multiplier.", required = true}},
	},
	capture_screenshot = {
		name = "capture_screenshot",
		description = "Capture a screenshot, optionally opening it in the file manager.",
		parameters = {mode = {type = "string", description = "Whether to save only or save and open the screenshot.", required = true, enum = {"save", "save_and_open"}}},
	},
	set_chart_search = {
		name = "set_chart_search",
		description = "Set the chart search query. Use an empty query to clear it.",
		parameters = {query = {type = "string", description = "Chart search text, or an empty string to clear search.", required = true}},
	},
	select_random_chart = {
		name = "select_random_chart",
		description = "Select a random chart.",
		parameters = {},
	},
	start_selected_chart = {
		name = "start_selected_chart",
		description = "Start the selected chart normally or with autoplay.",
		parameters = {mode = {type = "string", description = "How to start the selected chart.", required = true, enum = {"play", "autoplay"}}},
	},
	set_column_layout = {
		name = "set_column_layout",
		description = "Change the gameplay column layout.",
		parameters = {layout = {type = "string", description = "Column layout operation to apply.", required = true, enum = {"reset", "mirror", "bracketswap", "random_all", "random_left", "random_right"}}},
	},
	set_play_option = {
		name = "set_play_option",
		description = "Enable or disable a gameplay option.",
		parameters = {
			option = {type = "string", description = "Play option to change.", required = true, enum = {"auto_timings", "nearest", "tap_only", "const", "custom"}},
			enabled = {type = "boolean", description = "Whether the option should be enabled.", required = true},
		},
	},
	open_panel = {
		name = "open_panel",
		description = "Open a game configuration panel or the chart editor.",
		parameters = {panel = {type = "string", description = "Panel to open.", required = true, enum = {"modifiers", "filters", "input", "note_skins", "editor"}}},
	},
}

---@class rizu.ai.NeedleRoutingCase
---@field query string
---@field expected string
---@field arguments {[string]: string|number|boolean}?

---@type rizu.ai.NeedleRoutingCase[]
local cases = {
	{query = "rate 1", expected = "set_playback_rate", arguments = {rate = 1}},
	{query = "make song faster", expected = "set_playback_rate"},
	{query = "screenshot", expected = "capture_screenshot", arguments = {mode = "save_and_open"}},
	{query = "take screenshot", expected = "capture_screenshot", arguments = {mode = "save_and_open"}},
	{query = "autoplay", expected = "start_selected_chart"},
	{query = "start autoplay", expected = "start_selected_chart"},
	{query = "play chart", expected = "start_selected_chart", arguments = {mode = "play"}},
	{query = "mirror columns", expected = "set_column_layout", arguments = {layout = "mirror"}},
	{query = "randomize columns", expected = "set_column_layout"},
	{query = "open modifiers", expected = "open_panel", arguments = {panel = "modifiers"}},
	{query = "open editor", expected = "open_panel", arguments = {panel = "editor"}},
	{query = "disable const", expected = "set_play_option", arguments = {option = "const", enabled = false}},
}

---@param actual {[string]: unknown}?
---@param expected {[string]: string|number|boolean}?
---@return boolean
local function expected_arguments_match(actual, expected)
	if expected == nil then return true end
	if type(actual) ~= "table" then return false end
	for key, value in pairs(expected) do
		if actual[key] ~= value then return false end
	end
	return true
end

---@class rizu.ai.NeedleRoutingCall
---@field name string
---@field arguments {[string]: unknown}?

---@param text string
---@return rizu.ai.NeedleRoutingCall?
local function parse_call(text)
	local decoded = json.decode_safe(text)
	if type(decoded) ~= "table" or #decoded ~= 1 then return nil end
	---@diagnostic disable-next-line: no-unknown -- JSON values are intentionally dynamic until the checks below.
	local call = decoded[1]
	if type(call) ~= "table" or type(call.name) ~= "string" then return nil end
	return call
end

local routing_tools_json = json.encode(routing_tools)
local ctx = assert(needle.load(model_path))
local tokenizer = assert(ctx:createTokenizer())

local route_total = 0
local final_total = 0
local failed = 0
print(("model=%s routing_tools_bytes=%d run_final=%s"):format(model_path, #routing_tools_json, tostring(run_final)))

for _, case in ipairs(cases) do
	local query, expected = case.query, case.expected
	local src_ids = ctx:build_encoder_input(tokenizer, query, routing_tools_json, {max_enc_len = 1024})
	local streamed = ""
	local route_start = os.clock()
	local text, err = ctx:generate(query, routing_tools_json, {
		tokenizer = tokenizer,
		max_new_tokens = 48,
		constrained = true,
		use_cache = true,
		on_text = function(chunk)
			streamed = streamed .. chunk
			return streamed:match('"name":"[^"]+"') == nil
		end,
	})
	local route_elapsed = os.clock() - route_start
	local selected = streamed:match('"name":"([^"]+)"') or (text or ""):match('"name":"([^"]+)"')
	local route_ok = selected == expected
	local final_elapsed = 0
	local final_ok = true
	local final_text = nil
	local final_error = nil
	local call = nil
	if run_final and selected ~= nil then
		local selected_tool = assert(full_tools[selected])
		local selected_tools_json = json.encode({selected_tool})
		local final_start = os.clock()
		final_text, final_error = ctx:generate(query, selected_tools_json, {
			tokenizer = tokenizer,
			max_new_tokens = 96,
			constrained = true,
			use_cache = true,
		})
		final_elapsed = os.clock() - final_start
		call = final_text and parse_call(final_text)
		final_ok = call ~= nil and call.name == expected and expected_arguments_match(call.arguments, case.arguments)
	end
	local ok = route_ok and final_ok
	if not ok then failed = failed + 1 end
	route_total = route_total + route_elapsed
	final_total = final_total + final_elapsed
	print(("query=%q expected=%s selected=%s route_ok=%s final_ok=%s src_len=%d route_seconds=%.6f final_seconds=%.6f%s%s"):format(
		query,
		expected,
		tostring(selected),
		tostring(route_ok),
		tostring(final_ok),
		#src_ids,
		route_elapsed,
		final_elapsed,
		err and (" route_error=" .. err.message) or "",
		final_error and (" final_error=" .. final_error.message) or ""
	))
	if final_text then print("  final=" .. final_text) end
end

print(("avg_route_seconds=%.6f avg_final_seconds=%.6f avg_total_seconds=%.6f failures=%d/%d"):format(
	route_total / #cases,
	final_total / #cases,
	(route_total + final_total) / #cases,
	failed,
	#cases
))

tokenizer:close()
ctx:close()

if failed > 0 and os.getenv("ALLOW_FAILURES") ~= "1" then
	error("Needle routing benchmark failed")
end
