local class = require("class")

---@class ui.formatters.ScoreSystemFormatter
---@operator call: ui.formatters.ScoreSystemFormatter
local ScoreSystemFormatter = class()

local bms_alias = {"Easy", "Normal", "Hard", "Very hard"}
local fallback_grade_color = {0.51, 0.37, 0, 1}

local grade_colors = {
	osuod = {
		SS = {0.6, 0.8, 1, 1},
		S = {0.95, 0.796, 0.188, 1},
		A = {0.07, 0.8, 0.56, 1},
		B = {0.1, 0.39, 1, 1},
		C = {0.42, 0.48, 0.51, 1},
		D = fallback_grade_color,
	},
	etternaj = {
		AAAAA = {1, 1, 1, 1},
		AAAA = {0.6, 0.8, 1, 1},
		AAA = {0.95, 0.796, 0.188, 1},
		AA = {0.07, 0.8, 0.56, 1},
		A = {0, 0.7, 0.32, 1},
		B = {0.1, 0.7, 1, 1},
		C = {1, 0.1, 0.7, 1},
		F = fallback_grade_color,
	},
	quaver = {
		X = {0.6, 0.8, 1, 1},
		S = {0.95, 0.796, 0.188, 1},
		A = {0.95, 0.796, 0.188, 1},
		B = {0.07, 0.8, 0.56, 1},
		C = {0.1, 0.39, 1, 1},
		D = {0.42, 0.48, 0.51, 1},
		F = fallback_grade_color,
	},
	bmsrank = {
		AAA = {0.95, 0.796, 0.188, 1},
		AA = {0.07, 0.8, 0.56, 1},
		A = {0, 0.7, 0.32, 1},
		B = {0.1, 0.7, 1, 1},
		C = {1, 0.1, 0.7, 1},
		E = {1, 0.1, 0.7, 1},
		F = fallback_grade_color,
	},
}

---@param score_system rizu.ScoreSystem
function ScoreSystemFormatter:new(score_system)
	self.score_system = score_system
end

---@param score_system rizu.ScoreSystem
function ScoreSystemFormatter:setScoreSystem(score_system)
	self.score_system = score_system
end

---@return string
function ScoreSystemFormatter:getName()
	local timings = self.score_system.timings
	local subtimings = self.score_system.subtimings

	if not timings then
		return "No timings"
	end

	if timings.name == "sphere" then
		return "soundsphere"
	elseif timings.name == "osuod" then
		---@cast subtimings -?
		return ("osu!mania V%i OD%g"):format(subtimings.data, timings.data)
	elseif timings.name == "etternaj" then
		return ("Etterna J%i"):format(timings.data)
	elseif timings.name == "quaver" then
		return "Quaver standard"
	elseif timings.name == "bmsrank" then
		return ("LR2 %s"):format(bms_alias[timings.data])
	end

	return timings.name or "Unknown"
end

---@param accuracy number
---@return string
function ScoreSystemFormatter:getGrade(accuracy)
	local timings = self.score_system.timings
	local name = timings and timings.name

	if name == "osuod" then
		if accuracy == 1 then
			return "X"
		elseif accuracy > 0.95 then
			return "S"
		elseif accuracy > 0.9 then
			return "A"
		elseif accuracy > 0.8 then
			return "B"
		elseif accuracy > 0.7 then
			return "C"
		end
		return "D"
	elseif name == "etternaj" then
		if accuracy > 0.999935 then
			return "AAAAA"
		elseif accuracy > 0.99955 then
			return "AAAA"
		elseif accuracy > 0.997 then
			return "AAA"
		elseif accuracy > 0.93 then
			return "AA"
		elseif accuracy > 0.85 then
			return "A"
		elseif accuracy > 0.8 then
			return "B"
		elseif accuracy > 0.7 then
			return "C"
		end
		return "F"
	elseif name == "quaver" then
		if accuracy == 1 then
			return "X"
		elseif accuracy > 0.99 then
			return "SS"
		elseif accuracy > 0.95 then
			return "S"
		elseif accuracy > 0.9 then
			return "A"
		elseif accuracy > 0.8 then
			return "B"
		elseif accuracy > 0.7 then
			return "C"
		elseif accuracy > 0.6 then
			return "D"
		end
		return "F"
	elseif name == "bmsrank" then
		if accuracy > 0.8888 then
			return "AAA"
		elseif accuracy > 0.7777 then
			return "AA"
		elseif accuracy > 0.6666 then
			return "A"
		elseif accuracy > 0.5555 then
			return "B"
		elseif accuracy > 0.4444 then
			return "C"
		elseif accuracy > 0.3333 then
			return "D"
		elseif accuracy > 0.2222 then
			return "E"
		end
	end

	return "F"
end

---@param grade string
---@return gui.Color
function ScoreSystemFormatter:getGradeColor(grade)
	local timings = self.score_system.timings
	local colors = timings and grade_colors[timings.name]
	return colors and colors[grade] or fallback_grade_color
end

return ScoreSystemFormatter
