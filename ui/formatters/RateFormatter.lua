---The music speed the way the player sets it.
local RateFormatter = {}

---@param value number From `ui.api.play:getRateValue()`.
---@param rate_type sea.RateType
---@return string text "1.05x" or "+1"
function RateFormatter.format(value, rate_type)
	if rate_type == "exp" then
		return value > 0 and ("+%.0f"):format(value) or ("%.0f"):format(value)
	end
	return ("%.2fx"):format(value)
end

return RateFormatter
