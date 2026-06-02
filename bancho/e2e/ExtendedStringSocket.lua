--- ExtendedStringSocket wraps StringSocket to support IExtendedSocket patterns.
---
--- Adds receive("*a") and receive("*l") on top of StringSocket's receive(size).

local StringSocket = require("web.socket.StringSocket")
local IExtendedSocket = require("web.socket.IExtendedSocket")

local class = require("class")

--- ExtendedStringSocket wraps StringSocket with pattern-based receive.
---@class bancho.e2e.ExtendedStringSocket: web.IExtendedSocket
---@operator call: bancho.e2e.ExtendedStringSocket
---@field soc web.StringSocket
local ExtendedStringSocket = IExtendedSocket + {}

---@param data string?
---@param max_size integer?
function ExtendedStringSocket:new(data, max_size)
	self.soc = StringSocket(data, max_size)
	return self
end

--- Get the paired socket as another ExtendedStringSocket.
---@return bancho.e2e.ExtendedStringSocket
function ExtendedStringSocket:split()
	local pair_soc = self.soc:split()
	local pair = ExtendedStringSocket()
	pair.soc = pair_soc
	return pair
end

--- Receive with pattern support.
---@param pattern "*a"|"*l"|integer?
---@return string?
---@return "closed"|"timeout"?
function ExtendedStringSocket:receive(pattern)
	if pattern == "*a" then
		-- Read all remaining data
		local data = self.soc.remainder
		self.soc.remainder = ""
		if self.soc.closed then
			return nil, "closed"
		end
		return data or ""
	elseif pattern == "*l" then
		-- Read until \n, stripping \r\n
		local data = self.soc.remainder
		local line_end = data:find("\r\n")
		if not line_end then
			line_end = data:find("\n")
		end
		if not line_end then
			if self.soc.closed then
				return nil, "closed"
			end
			return nil, "timeout"
		end
		local line = data:sub(1, line_end - 1)
		self.soc.remainder = data:sub(line_end + 2)
		return line
	else
		-- Numeric size
		return self.soc:receive(pattern)
	end
end

--- Send data to the paired socket.
---@param data string
---@return integer?
---@return "closed"|"timeout"?
function ExtendedStringSocket:send(data)
	return self.soc:send(data)
end

--- Close the socket.
---@return 1
function ExtendedStringSocket:close()
	return self.soc:close()
end

--- Receive any available data up to max bytes.
---@param max integer
---@return string?
---@return "closed"|"timeout"?
function ExtendedStringSocket:receiveany(max)
	local data = self.soc.remainder
	if #data > max then
		self.soc.remainder = data:sub(max + 1)
		data = data:sub(1, max)
	else
		self.soc.remainder = ""
	end
	if #data == 0 and self.soc.closed then
		return nil, "closed"
	end
	return data
end

return ExtendedStringSocket
