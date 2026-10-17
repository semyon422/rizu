local stbl = require("stbl")

local ComputeProtocol = {}

ComputeProtocol.max_payload_size = 64 * 1024 * 1024

---@param socket web.ISocket
---@param size integer
---@return string?
---@return string?
local function receive_exact(socket, size)
	local chunks = {}
	local received = 0
	while received < size do
		local chunk, err, partial = socket:receive(size - received)
		chunk = chunk or partial
		if chunk and #chunk > 0 then
			table.insert(chunks, chunk)
			received = received + #chunk
		end
		if err and received < size then
			return nil, err
		end
	end
	return table.concat(chunks)
end

---@param socket web.ISocket
---@param value table
---@param max_payload_size integer?
---@return true?
---@return string?
function ComputeProtocol.send(socket, value, max_payload_size)
	local payload = stbl.encode(value)
	local limit = max_payload_size or ComputeProtocol.max_payload_size
	if #payload > limit then
		return nil, "payload too large"
	end

	local data = ("%08x"):format(#payload) .. payload
	local sent, err = socket:send(data)
	if not sent then
		return nil, err
	end
	return true
end

---@param socket web.ISocket
---@param max_payload_size integer?
---@return table?
---@return string?
function ComputeProtocol.receive(socket, max_payload_size)
	local header, err = receive_exact(socket, 8)
	if not header then
		return nil, "receive header: " .. tostring(err)
	end
	if not header:match("^[0-9a-fA-F]+$") then
		return nil, "invalid payload header"
	end

	local size = tonumber(header, 16)
	local limit = max_payload_size or ComputeProtocol.max_payload_size
	if not size or size <= 0 or size > limit then
		return nil, "invalid payload size"
	end

	local payload
	payload, err = receive_exact(socket, size)
	if not payload then
		return nil, "receive payload: " .. tostring(err)
	end

	local ok, value = pcall(stbl.decode, payload)
	if not ok or type(value) ~= "table" then
		return nil, "invalid payload"
	end
	return value
end

return ComputeProtocol
