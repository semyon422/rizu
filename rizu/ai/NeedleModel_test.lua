local NeedleModel = require("rizu.ai.NeedleModel")

local test = {}

local function makeTransport()
	local transport = {sent = {}, output = {}}
	function transport:start(config) self.config = config end
	function transport:send(event) self.sent[#self.sent + 1] = event end
	function transport:pop() return table.remove(self.output, 1) end
	function transport:checkError() end
	function transport:stop() self.stopped = true end
	return transport
end

local function makeToolSet(executed)
	local tool = {
		name = "select_random_chart",
		description = "Select a random chart.",
		parameters = {type = "object", properties = {}, required = {}},
		argument_order = {},
		execute = function() executed.count = executed.count + 1 end,
	}
	return {tools = {tool}, by_name = {[tool.name] = tool}, tools_json = "[]"}
end

---@param t testing.T
function test.debounce_and_execute(t)
	local now = 10
	local transport = makeTransport()
	local executed = {count = 0}
	local model = NeedleModel({model_path = "model", debounce_seconds = 0.25, max_new_tokens = 64}, transport, function() return now end)
	model:activate(makeToolSet(executed))
	model:setQuery("random chart")
	model:update()
	t:eq(#transport.sent, 0)
	now = 10.25
	model:update()
	t:eq(transport.sent[1].type, "generate")
	local request_id = transport.sent[1].request_id
	transport.output[1] = {type = "reset", request_id = request_id, content = '[{"name":"'}
	transport.output[2] = {type = "delta", request_id = request_id, content = "select_random_chart"}
	transport.output[3] = {type = "complete", request_id = request_id, content = '[{"name":"select_random_chart","arguments":{}}]'}
	model:update()
	t:eq(model.state, "ready")
	t:eq(model.formatted_call, "select_random_chart()")
	t:eq(model:execute(), true)
	t:eq(executed.count, 1)
end

---@param t testing.T
function test.stale_result_is_ignored(t)
	local now = 0
	local transport = makeTransport()
	local model = NeedleModel({model_path = "model", debounce_seconds = 0, max_new_tokens = 64}, transport, function() return now end)
	model:activate(makeToolSet({count = 0}))
	model:setQuery("first")
	model:update()
	local stale_id = transport.sent[1].request_id
	model:setQuery("second")
	model:update()
	transport.output[1] = {type = "complete", request_id = stale_id, content = '[{"name":"select_random_chart","arguments":{}}]'}
	model:update()
	t:ne(model.state, "ready")
	local ok = model:execute()
	t:eq(ok, false)
end

---@param t testing.T
function test.cancel_and_invalid_output(t)
	local transport = makeTransport()
	local model = NeedleModel({model_path = "model", debounce_seconds = 0, max_new_tokens = 64}, transport, function() return 0 end)
	model:activate(makeToolSet({count = 0}))
	model:setQuery("random")
	model:update()
	local request_id = transport.sent[1].request_id
	model:cancel()
	t:eq(transport.sent[2].type, "cancel")
	t:eq(model.state, "idle")
	transport.output[1] = {type = "complete", request_id = request_id, content = "not json"}
	model:update()
	t:eq(model.state, "idle")

	model:setQuery("random")
	model:update()
	request_id = transport.sent[#transport.sent].request_id
	transport.output[1] = {type = "complete", request_id = request_id, content = "not json"}
	model:update()
	t:eq(model.state, "error")
	t:assert(model.error:find("invalid tool-call JSON", 1, true))
end

---@param t testing.T
function test.unavailable_worker(t)
	local transport = makeTransport()
	local model = NeedleModel({model_path = "missing", debounce_seconds = 0.25, max_new_tokens = 64}, transport, function() return 0 end)
	model:activate(makeToolSet({count = 0}))
	transport.output[1] = {type = "unavailable", error = "missing model"}
	model:update()
	t:eq(model.state, "unavailable")
	t:eq(model.error, "missing model")
	model:unload()
	t:eq(transport.stopped, true)
end

return test
