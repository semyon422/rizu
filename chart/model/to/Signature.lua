local class = require("class")

---@class chart.Signature
---@operator call: chart.Signature
local Signature = class()

---@param signature chart.Fraction?
function Signature:new(signature)  -- nil = use default signature
	self.signature = signature
end

---@param a chart.Signature
---@return string
function Signature.__tostring(a)
	return ("Signature(%s)"):format(a.signature or "default")
end

return Signature
