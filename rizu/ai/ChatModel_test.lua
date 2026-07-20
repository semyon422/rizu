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
	t:eq(#model.messages, 2)
	t:eq(model.messages[2].role, "user")
	t:eq(model.messages[2].content, "hello")
end

---@param t testing.T
function test.failed_followup_after_tool_preserves_initial_prompt_and_complete_protocol(t)
	local run_count = 0
	local model = ChatModel(makeAgent(function(messages)
		run_count = run_count + 1
		if run_count == 1 then
			table.insert(messages, {
				role = "assistant",
				tool_calls = {{
					id = "call_1",
					type = "function",
					["function"] = {name = "lua_eval", arguments = "{}"},
				}},
			})
			table.insert(messages, {role = "tool", tool_call_id = "call_1", content = "result"})
			return nil, "followup failed"
		end

		t:eq(messages[2].role, "user")
		t:eq(messages[2].content, "Get my IP")
		t:eq(messages[3].role, "assistant")
		t:eq(messages[4].role, "tool")
		local reply = {role = "assistant", content = "continuing"}
		table.insert(messages, reply)
		return reply
	end), "system")

	model:send("Get my IP")
	t:eq(#model.messages, 4)
	t:eq(model.entries[2].role, "error")

	model:send("continue")
	t:eq(model.entries[#model.entries].content, "continuing")
end

---@param t testing.T
function test.failure_removes_incomplete_tool_group_but_preserves_user(t)
	local model = ChatModel(makeAgent(function(messages)
		table.insert(messages, {
			role = "assistant",
			tool_calls = {
				{id = "call_1", type = "function", ["function"] = {name = "one", arguments = "{}"}},
				{id = "call_2", type = "function", ["function"] = {name = "two", arguments = "{}"}},
			},
		})
		table.insert(messages, {role = "tool", tool_call_id = "call_1", content = "result"})
		error("tool callback failed")
	end), "system")

	model:send("inspect")

	t:eq(#model.messages, 2)
	t:eq(model.messages[2].role, "user")
	t:eq(model.messages[2].content, "inspect")
	t:eq(model.entries[#model.entries].role, "error")
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
