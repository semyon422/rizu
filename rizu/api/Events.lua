local class = require("class")

---What every API area inherits: `area:on(event, f)`.
---@class rizu.api.Events
---@operator call: rizu.api.Events
---@field private listeners {[string]: function[]}
local Events = class()

function Events:new()
	self.listeners = {}
end

---Calls f every time the event happens. Returns a function that stops it.
---@param event string
---@param f function
---@return fun() unsubscribe
function Events:on(event, f)
	local listeners = self.listeners[event] or {}
	self.listeners[event] = listeners
	listeners[#listeners + 1] = f
	return function()
		for i, listener in ipairs(listeners) do
			if listener == f then
				table.remove(listeners, i)
				return
			end
		end
	end
end

---For the API itself, not for user interfaces.
---@param event string
---@param ... any
function Events:emit(event, ...)
	for _, f in ipairs(self.listeners[event] or {}) do
		f(...)
	end
end

return Events
