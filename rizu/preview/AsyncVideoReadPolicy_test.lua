local AsyncVideoReadPolicy = require("rizu.preview.AsyncVideoReadPolicy")

local test = {}

---@param t testing.T
function test.first_requested_frame_uses_seek(t)
	local use_seek, reason = AsyncVideoReadPolicy.shouldSeek(nil, 10, 30)

	t:eq(use_seek, true)
	t:eq(reason, "initial")
end

---@param t testing.T
function test.batch_continuation_uses_read(t)
	local use_seek, reason = AsyncVideoReadPolicy.shouldSeek(10, nil, 30)

	t:eq(use_seek, false)
	t:eq(reason, "read")
end

---@param t testing.T
function test.backward_request_uses_seek(t)
	local use_seek, reason = AsyncVideoReadPolicy.shouldSeek(10, 9, 30)

	t:eq(use_seek, true)
	t:eq(reason, "backward")
end

---@param t testing.T
function test.near_sequential_request_uses_read(t)
	local use_seek, reason = AsyncVideoReadPolicy.shouldSeek(10, 10 + 1 / 30, 30)

	t:eq(use_seek, false)
	t:eq(reason, "read")
end

---@param t testing.T
function test.large_forward_jump_uses_seek(t)
	local use_seek, reason = AsyncVideoReadPolicy.shouldSeek(10, 10 + 4 / 30, 30)

	t:eq(use_seek, true)
	t:eq(reason, "jump")
end

return test
