require("pkg_config")
require("love.thread")
require("love.timer")

local needle = require("ai.needle")
local json = require("web.json")

local input_name, output_name, model_path, max_new_tokens = ...
local input_channel = love.thread.getChannel(input_name)
local output_channel = love.thread.getChannel(output_name)

local context, load_error = needle.load(model_path)
if not context or not context:is_loaded() then
	output_channel:push({type = "unavailable", error = load_error and load_error.message or "could not load Needle model"})
	if context then context:close() end
	return
end
local tokenizer, tokenizer_error = context:createTokenizer()
if not tokenizer or tokenizer_error then
	output_channel:push({type = "unavailable", error = tokenizer_error and tokenizer_error.message or "could not load embedded tokenizer"})
	if tokenizer then tokenizer:close() end
	context:close()
	return
end

output_channel:push({type = "ready"})

local pending
local stopping = false
local cancelled_ids = {}

---@param request_id integer
local function pollControl(request_id)
	local interrupted = false
	while true do
		local event = input_channel:pop()
		if not event then break end
		if event.type == "stop" then
			stopping = true
			return false
		elseif event.type == "generate" then
			pending = event
			interrupted = true
		elseif event.type == "cancel" then
			cancelled_ids[event.request_id] = true
			if event.request_id == request_id then interrupted = true end
		end
	end
	return not interrupted
end

---@param event table
---@param telemetry table
---@param phase string
---@param tools_json string
---@param token_limit integer
---@param on_text fun(chunk: string): boolean
---@return string? text
---@return string? error_message
local function generate(event, telemetry, phase, tools_json, token_limit, on_text)
	local phase_start = love.timer.getTime()
	local prefill_end
	telemetry[phase .. "_layers_completed"] = 0
	local text, err = context:generate(event.query, tools_json, {
		tokenizer = tokenizer,
		max_new_tokens = token_limit,
		constrained = true,
		use_cache = true,
		on_prefill_progress = function(completed, total)
			telemetry[phase .. "_layers_completed"] = completed
			telemetry[phase .. "_layers_total"] = total
			if completed == total then prefill_end = love.timer.getTime() end
			return pollControl(event.request_id)
		end,
		on_text = on_text,
	})
	local phase_end = love.timer.getTime()
	telemetry[phase .. "_prefill_seconds"] = (prefill_end or phase_end) - phase_start
	telemetry[phase .. "_decode_seconds"] = prefill_end and phase_end - prefill_end or 0
	return text, err and err.message
end

local function generateCall(event, tool, telemetry)
	local selected_tools_json = json.encode({tool})
	output_channel:push({type = "reset", request_id = event.request_id, content = ""})
	return generate(event, telemetry, "final", selected_tools_json, max_new_tokens, function(chunk)
			output_channel:push({type = "delta", request_id = event.request_id, content = chunk})
			return pollControl(event.request_id)
	end)
end

local function pushTerminal(event, event_type, telemetry, fields)
	telemetry.total_seconds = love.timer.getTime() - telemetry.started_at
	telemetry.started_at = nil
	fields = fields or {}
	fields.type = event_type
	fields.request_id = event.request_id
	fields.telemetry = telemetry
	output_channel:push(fields)
end

while not stopping do
	local event = pending
	pending = nil
	if not event then event = input_channel:demand() end
	if event.type == "stop" then
		break
	elseif event.type == "generate" then
		local started_at = love.timer.getTime()
		local telemetry = {
			started_at = started_at,
			queue_seconds = event.enqueued_at and math.max(0, started_at - event.enqueued_at) or 0,
			tool_count = 0,
		}
		if cancelled_ids[event.request_id] then
			cancelled_ids[event.request_id] = nil
			pushTerminal(event, "cancelled", telemetry)
			goto continue
		end
		output_channel:push({type = "started", request_id = event.request_id, telemetry = telemetry})
		local tools, tools_error = json.decode_safe(event.tools_json)
		if not tools or #tools == 0 then
			pushTerminal(event, "error", telemetry, {error = tostring(tools_error or "no tools available")})
			goto continue
		end
		telemetry.tool_count = #tools

		local selected_tool = tools[1]
		if #tools > 1 then
			local routing_text = ""
			local selected_name
			generate(event, telemetry, "routing", event.tools_json, 48, function(chunk)
					routing_text = routing_text .. chunk
					selected_name = routing_text:match('"name":"([^"]+)"')
					return selected_name == nil and pollControl(event.request_id)
			end)
			if stopping then break end
			if pending or cancelled_ids[event.request_id] then
				cancelled_ids[event.request_id] = nil
				pushTerminal(event, "cancelled", telemetry)
				goto continue
			end
			selected_tool = nil
			for _, tool in ipairs(tools) do
				if tool.name == selected_name then selected_tool = tool break end
			end
			if not selected_tool then
				pushTerminal(event, "error", telemetry, {error = "Needle could not select a tool"})
				goto continue
			end
		end
		telemetry.selected_tool = selected_tool.name

		local text, err = generateCall(event, selected_tool, telemetry)
		if stopping then break end
		if pending or cancelled_ids[event.request_id] then
			cancelled_ids[event.request_id] = nil
			pushTerminal(event, "cancelled", telemetry)
		elseif text then
			pushTerminal(event, "complete", telemetry, {content = text})
		else
			pushTerminal(event, "error", telemetry, {error = err or "Needle generation failed"})
		end
	end
	::continue::
end

tokenizer:close()
context:close()
