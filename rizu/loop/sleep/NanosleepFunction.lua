local ISleepFunction = require("rizu.loop.sleep.ISleepFunction")
local ffi = require("ffi")

---@class rizu.NanosleepFunction: rizu.ISleepFunction
---@operator call: rizu.NanosleepFunction
local NanosleepFunction = ISleepFunction + {}

function NanosleepFunction:new()
	ffi.cdef [[
		struct timespec {
			long tv_sec;
			long tv_nsec;
		};
		int nanosleep(const struct timespec *__requested_time, struct timespec *__remaining);
	]]
	---@type {[0]: {tv_sec: integer, tv_nsec: integer}}
	self.rt = ffi.new("struct timespec[1]")
end

function NanosleepFunction:sleep(s)
	if s <= 0 then return end
	local i, f = math.modf(s)
	self.rt[0].tv_sec = i
	self.rt[0].tv_nsec = f * 1e9
	ffi.C.nanosleep(self.rt, nil)
end

function NanosleepFunction:isAvailable(os_name)
	return os_name ~= "Windows"
end

return NanosleepFunction
