local ChatModel = require("rizu.ai.ChatModel")

local test = {}

---@param run fun(messages: aqua.openai.Message[], on_text_delta: fun(content: string)?): aqua.openai.Message?, string?
---@return aqua.openai.Agent
local function makeAgent(run)
	return {
		run = function(_, messages, on_text_delta) return run(messages, on_text_delta) end,
		cancel = function() return true end,
	}
end

---@param t testing.T
function test.sends_and_clears_conversation(t)
	local model = ChatModel(makeAgent(function(messages)
		t:eq(messages[#messages].content, "hello")
		local reply = {role = "assistant", content = "hi"}
		table.insert(messages, reply)
		return reply
	end), "system")

	local ok = model:send("hello")
	t:eq(ok, true)
	t:eq(model.busy, false)
	t:eq(#model.entries, 2)
	t:eq(model.entries[2].content, "hi")
	t:eq(model:clear(), true)
	t:eq(#model.entries, 0)
	t:eq(#model.messages, 1)
end

---@param t testing.T
function test.validates_input_and_reports_errors(t)
	local model = ChatModel(makeAgent(function()
		return nil, "offline"
	end), "system")

	local ok, err = model:send("  ")
	t:eq(ok, false)
	t:eq(err, "message is empty")
	ok = model:send("hello")
	t:eq(ok, true)
	t:eq(model.entries[2].role, "error")
	t:eq(model.entries[2].content, "offline")
	t:eq(#model.messages, 1)
end

---@param t testing.T
function test.tool_events_are_visible(t)
	local agent
	agent = makeAgent(function(messages)
		agent.on_tool_result({["function"] = {name = "lua_eval"}}, "result")
		local reply = {role = "assistant", content = "done"}
		table.insert(messages, reply)
		return reply
	end)
	local model = ChatModel(agent, "system")
	model:send("inspect")
	t:eq(model.entries[2].role, "tool")
	t:eq(model.entries[2].name, "lua_eval")
end

---@param t testing.T
function test.streaming_updates_one_assistant_entry(t)
	local model = ChatModel(makeAgent(function(messages, on_text_delta)
		on_text_delta("hel")
		on_text_delta("lo")
		local reply = {role = "assistant", content = "hello"}
		table.insert(messages, reply)
		return reply
	end), "system")
	model:send("stream")
	t:eq(#model.entries, 2)
	t:eq(model.entries[2].role, "assistant")
	t:eq(model.entries[2].content, "hello")
end

---@param t testing.T
function test.cancel_preserves_partial_transcript_and_discards_protocol_turn(t)
	local canceled = false
	local model
	local agent = makeAgent(function(_, on_text_delta)
		on_text_delta("partial")
		model:cancel()
		return nil, "canceled"
	end)
	agent.cancel = function()
		canceled = true
		return true
	end
	model = ChatModel(agent, "system")
	model:send("stop")
	t:eq(canceled, true)
	t:eq(model.busy, false)
	t:eq(#model.messages, 1)
	t:eq(#model.entries, 2)
	t:eq(model.entries[2].content, "partial")
	t:eq(model:cancel(), false)
end

return test
