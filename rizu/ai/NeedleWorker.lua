require("pkg_config")
require("love.thread")

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
local cancelled_id

local function pollControl()
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
			cancelled_id = event.request_id
			interrupted = true
		end
	end
	return not interrupted
end

local function generateCall(event, tool)
	local selected_tools_json = json.encode({tool})
	output_channel:push({type = "reset", request_id = event.request_id, content = ""})
	local text, err = context:generate(event.query, selected_tools_json, {
		tokenizer = tokenizer,
		max_new_tokens = max_new_tokens,
		constrained = true,
		use_cache = true,
		on_text = function(chunk)
			output_channel:push({type = "delta", request_id = event.request_id, content = chunk})
			return pollControl()
		end,
	})
	return text, err and err.message
end

while not stopping do
	local event = pending
	pending = nil
	if not event then event = input_channel:demand() end
	if event.type == "stop" then
		break
	elseif event.type == "generate" then
		cancelled_id = nil
		output_channel:push({type = "started", request_id = event.request_id})
		local tools, tools_error = json.decode_safe(event.tools_json)
		if not tools or #tools == 0 then
			output_channel:push({type = "error", request_id = event.request_id, error = tostring(tools_error or "no tools available")})
			goto continue
		end

		local selected_tool = tools[1]
		if #tools > 1 then
			local routing_text = ""
			local selected_name
			context:generate(event.query, event.tools_json, {
				tokenizer = tokenizer,
				max_new_tokens = 48,
				constrained = true,
				use_cache = true,
				on_text = function(chunk)
					routing_text = routing_text .. chunk
					selected_name = routing_text:match('"name":"([^"]+)"')
					return selected_name == nil and pollControl()
				end,
			})
			if stopping then break end
			if pending or cancelled_id == event.request_id then
				output_channel:push({type = "cancelled", request_id = event.request_id})
				goto continue
			end
			selected_tool = nil
			for _, tool in ipairs(tools) do
				if tool.name == selected_name then selected_tool = tool break end
			end
			if not selected_tool then
				output_channel:push({type = "error", request_id = event.request_id, error = "Needle could not select a tool"})
				goto continue
			end
		end

		local text, err = generateCall(event, selected_tool)
		if stopping then break end
		if pending or cancelled_id == event.request_id then
			output_channel:push({type = "cancelled", request_id = event.request_id})
		elseif text then
			output_channel:push({type = "complete", request_id = event.request_id, content = text})
		else
			output_channel:push({type = "error", request_id = event.request_id, error = err or "Needle generation failed"})
		end
	end
	::continue::
end

tokenizer:close()
context:close()
