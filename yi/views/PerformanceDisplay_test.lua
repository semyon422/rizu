local test = {}

local function make_transform()
	return {
		setTransformation = function(self, x, y, _r, sx, sy)
			self.x = x or 0
			self.y = y or 0
			self.sx = sx or 1
			self.sy = sy or 1
			return self
		end,
		reset = function(self)
			self.x = 0
			self.y = 0
			self.sx = 1
			self.sy = 1
			return self
		end,
		apply = function(self, other)
			self.x = self.x + (other.x or 0) * self.sx
			self.y = self.y + (other.y or 0) * self.sy
			self.sx = self.sx * (other.sx or 1)
			self.sy = self.sy * (other.sy or 1)
			return self
		end,
	}
end

_G.love = _G.love or {}
love.math = love.math or {}
love.math.newTransform = love.math.newTransform or make_transform
love.math.colorFromBytes = love.math.colorFromBytes or function(r, g, b, a)
	return r / 255, g / 255, b / 255, (a or 255) / 255
end
love.timer = love.timer or {}
love.timer.getTime = love.timer.getTime or function()
	return 0
end

local PerformanceDisplay = require("yi.views.PerformanceDisplay")

---@param t testing.T
function test.format_stats_includes_fps_and_frame_latency(t)
	t:eq(PerformanceDisplay.formatStats(240, 1 / 240), "240fps\n4.2ms")
	t:eq(PerformanceDisplay.formatStats(60, 1 / 60), "60fps\n16.7ms")
end

return test
