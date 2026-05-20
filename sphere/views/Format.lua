local int_rates = require("chart.scoring.int_rates")

local Format = {}

---@param score any
---@return string
function Format.accuracy(score)
	score = tonumber(score)
	if not score or score >= 0.1 or score <= -0.1 then
		return "100+"
	end
	return ("%2.2f"):format(score * 1000)
end

---@param difficulty number
---@return string
function Format.difficulty(difficulty)
	local format = "%.2f"
	if not difficulty then
		return ""
	elseif difficulty ~= difficulty then
		return "nan"
	elseif difficulty >= 10000 then
		format = "%s"
		difficulty = "????"
	elseif difficulty >= 100 then
		format = "%d"
	elseif difficulty > 9.995 then
		format = "%.1f"
	end
	return format:format(difficulty)
end

---@param rate number
---@return string
function Format.timeRate(rate)
	local exp = int_rates.get_exp(rate, 10)
	if int_rates.is_q_rate(rate, 10) and rate % 1 ~= 0 then
		return ("%dQ"):format(exp)
	end
	return ("%.2f"):format(rate)
end

---@param inputMode any?
---@return string
function Format.inputMode(inputMode)
	if type(inputMode) ~= "string" then
		return ""
	end
	inputMode = inputMode
		:gsub("key", "K")
		:gsub("scratch", "S")
		:gsub("pedal", "P")
	return inputMode
end

return Format
