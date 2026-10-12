local Events = require("rizu.api.Events")

---`rizu.api.Play` that only remembers the music speed.
---@class rizu.api.fake.FakePlay : rizu.api.Events
---@operator call: rizu.api.fake.FakePlay
local FakePlay = Events + {}

function FakePlay:new()
	Events.new(self)
	self.rate = 1
end

function FakePlay:getRate() return self.rate end
function FakePlay:getRateType() return "linear" end
function FakePlay:getRateText() return ("%.2fx"):format(self.rate) end

function FakePlay:changeRate(steps)
	self.rate = math.max(0.25, math.min(self.rate + steps * 0.05, 4))
	self:emit("rate_changed")
end

function FakePlay:getModCount() return 0 end
function FakePlay:getMutatorCount() return 0 end
function FakePlay:prepare(autoplay) end

return FakePlay
