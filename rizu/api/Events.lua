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
---A listener that throws is reported and does not stop the others.
---@param event string
---@param f function
---@return fun() unsubscribe
function Events:on(event, f)
	-- The arrays are replaced, never changed, so emit can walk one while a listener unsubscribes.
	local old = self.listeners[event] or {}
	local listeners = table.move(old, 1, #old, 1, {})
	listeners[#listeners + 1] = f
	self.listeners[event] = listeners
	return function()
		local current = self.listeners[event]
		for i, listener in ipairs(current or {}) do
			if listener == f then
				local rest = table.move(current, 1, #current, 1, {})
				table.remove(rest, i)
				self.listeners[event] = rest
				return
			end
		end
	end
end

---Forgets every listener. The game calls this when it replaces the user interface.
function Events:removeListeners()
	self.listeners = {}
end

---For the API itself, not for user interfaces.
---@param event string
---@param ... any
function Events:emit(event, ...)
	for _, f in ipairs(self.listeners[event] or {}) do
		local ok, err = xpcall(f, debug.traceback, ...)
		if not ok then
			print(("rizu.api: listener of %q failed:\n%s"):format(event, err))
		end
	end
end

return Events
