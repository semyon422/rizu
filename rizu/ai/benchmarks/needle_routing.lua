local needle = require("ai.needle")
local json = require("web.json")

local model_path = arg[1] or os.getenv("NEEDLE_MODEL_PATH") or "resources/needle/needle-q8-stripped.bin"

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

local cases = {
	{"rate 1", "set_playback_rate"},
	{"make song faster", "set_playback_rate"},
	{"screenshot", "capture_screenshot"},
	{"take screenshot", "capture_screenshot"},
	{"autoplay", "start_selected_chart"},
	{"start autoplay", "start_selected_chart"},
	{"play chart", "start_selected_chart"},
	{"mirror columns", "set_column_layout"},
	{"randomize columns", "set_column_layout"},
	{"open modifiers", "open_panel"},
	{"open editor", "open_panel"},
	{"disable const", "set_play_option"},
}

local routing_tools_json = json.encode(routing_tools)
local ctx = assert(needle.load(model_path))
local tokenizer = assert(ctx:createTokenizer())

local total = 0
local failed = 0
print(("model=%s tools_bytes=%d"):format(model_path, #routing_tools_json))

for _, case in ipairs(cases) do
	local query, expected = case[1], case[2]
	local src_ids = ctx:build_encoder_input(tokenizer, query, routing_tools_json, {max_enc_len = 1024})
	local streamed = ""
	local start = os.clock()
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
	local elapsed = os.clock() - start
	local selected = streamed:match('"name":"([^"]+)"') or (text or ""):match('"name":"([^"]+)"')
	local ok = selected == expected
	if not ok then failed = failed + 1 end
	total = total + elapsed
	print(("query=%q expected=%s selected=%s ok=%s src_len=%d seconds=%.6f%s"):format(
		query,
		expected,
		tostring(selected),
		tostring(ok),
		#src_ids,
		elapsed,
		err and (" error=" .. err.message) or ""
	))
end

print(("avg_seconds=%.6f failures=%d/%d"):format(total / #cases, failed, #cases))

tokenizer:close()
ctx:close()

if failed > 0 and os.getenv("ALLOW_FAILURES") ~= "1" then
	error("Needle routing benchmark failed")
end
