local class = require("class")

---@class rizu.sdvx.Knob
---@operator call: rizu.sdvx.Knob
---@field previous number?
local Knob = class()

---@param sensitivity number
---@param inverted boolean
---@param deadzone number
function Knob:new(sensitivity, inverted, deadzone)
	assert(sensitivity > 0 and sensitivity < math.huge)
	assert(deadzone >= 0 and deadzone < 1)
	self.sensitivity = sensitivity
	self.inverted = inverted
	self.deadzone = deadzone
end

-- Wrapped absolute encoder values in [-1, 1], not a stick velocity axis.
---@param value number
---@param paused boolean?
---@return number
function Knob:sample(value, paused)
	assert(value >= -1 and value <= 1, "Invalid SDVX encoder axis.")
	local previous = self.previous
	self.previous = value
	if previous == nil or paused then return 0 end
	local delta = value - previous
	if delta > 1.5 then delta = delta - 2 elseif delta < -1.5 then delta = delta + 2 end
	if math.abs(delta) < self.deadzone then return 0 end
	return delta * self.sensitivity * (self.inverted and -1 or 1)
end

function Knob:reset()
	self.previous = nil
end

return Knob
