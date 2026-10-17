local class = require("class")
local just = require("just")

---@class rizu.LoopGraphics
---@operator call: rizu.LoopGraphics
local LoopGraphics = class()

---@param loop rizu.Loop
function LoopGraphics:new(loop)
	self.loop = loop
	self.dwm_flush = false
	self.dwmapi = nil
	if love.system.getOS() == "Windows" then
		local ffi = require("ffi")
		local ok, res = pcall(ffi.load, "dwmapi")
		if ok then
			self.dwmapi = res
			ffi.cdef("void DwmFlush();")
		end
	end
end

function LoopGraphics:draw()
	if love.graphics and love.graphics.isActive() then
		love.graphics.origin()
		love.graphics.clear(love.graphics.getBackgroundColor())
		self.loop.events:dispatchEvent("draw")
		just._end()
		love.graphics.origin()
		love.graphics.getStats(self.loop.stats)
	end
end

function LoopGraphics:present()
	if love.graphics and love.graphics.isActive() then
		love.graphics.present()
		self:onPresent()
	end
end

function LoopGraphics:onPresent()
	if self.dwmapi and self.dwm_flush then
		self.dwmapi.DwmFlush()
	end
end

return LoopGraphics
