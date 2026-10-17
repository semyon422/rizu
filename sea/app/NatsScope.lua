local class = require("class")
local table_util = require("table_util")

---@class sea.NatsScopeContext
---@field rizu_nats nats.INats?

---@class sea.NatsScope
---@operator call: sea.NatsScope
local NatsScope = class()

---@param context fun(): sea.NatsScopeContext
---@param create fun(): nats.INats
function NatsScope:new(context, create)
	self.context = context
	self.create = create
end

---@return nats.INats
function NatsScope:get()
	local context = self.context()
	if not context.rizu_nats then
		context.rizu_nats = self.create()
	end
	return context.rizu_nats
end

---@param callback fun(...: any): ...any
---@param ... any
---@return any ...
function NatsScope:call(callback, ...)
	local context = self.context()
	local results = table_util.pack(xpcall(callback, debug.traceback, ...))
	local connection = context.rizu_nats
	context.rizu_nats = nil
	if connection then
		connection:close()
	end
	if not results[1] then
		error(results[2], 0)
	end
	return unpack(results, 2, results.n)
end

return NatsScope
