local class = require("class")

---@class chart.Tempo
---@operator call: chart.Tempo
---@field point chart.Point
local Tempo = class()

---@param tempo number
function Tempo:new(tempo)
	self.tempo = tempo
end

---@return number
function Tempo:getBeatDuration()
	return 60 / self.tempo
end

---@param a chart.Tempo
---@return string
function Tempo.__tostring(a)
	return ("Tempo(%s)"):format(a.tempo)
end

return Tempo
