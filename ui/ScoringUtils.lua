local ScoringUtils = {}

---@param timings_name sea.TimingsName
---@param accuracy number
---@return string?
function ScoringUtils.getGrade(timings_name, accuracy)
	if timings_name == "osuod" then
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
		else
			return "D"
		end
	elseif timings_name == "etternaj" then
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
		else
			return "F"
		end
	elseif timings_name == "quaver" then
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
		else
			return "F"
		end
	elseif timings_name == "bmsrank" then
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
		else
			return "F"
		end
	end
end

---@param grade string?
---@return string
function ScoringUtils.convertGradeToOsu(grade)
	if grade == "AAAAA" or grade == "AAAA" or grade == "AAA" or grade == "SS" then
		return "X"
	elseif grade == "AA" then
		return "S"
	else
		return "D"
	end
end

local bms_alias = {"Easy", "Normal", "Hard", "Very hard"}

---@param timings sea.Timings?
---@param subtimings sea.Subtimings?
---@return string
function ScoringUtils.formatScoreSystemName(timings, subtimings)
	if not timings then
		return "No timings"
	end

	if timings.name == "sphere" then
		return "soundsphere"
	elseif timings.name == "osuod" then
		---@cast subtimings -?
		return ("osu!mania V%i OD%i"):format(subtimings.data, timings.data)
	elseif timings.name == "etternaj" then
		return ("Etterna J%i"):format(timings.data)
	elseif timings.name == "quaver" then
		return "Quaver standard"
	elseif timings.name == "bmsrank" then
		return ("LR2 %s"):format(bms_alias[timings.data])
	end

	return timings.name or "Unknown"
end

ScoringUtils.judgeColors = {
	sphere = {
		{1, 1, 1, 1},
		{1, 0.6, 0.4, 1},
	},
	osuod = {
		{0.6, 0.8, 1, 1},
		{0.95, 0.796, 0.188, 1},
		{0.07, 0.8, 0.56, 1},
		{0.1, 0.39, 1, 1},
		{0.42, 0.48, 0.51, 1},
	},
	etternaj = {
		{0.6, 0.8, 1, 1},
		{0.95, 0.796, 0.188, 1},
		{0.07, 0.8, 0.56, 1},
		{0.1, 0.7, 1, 1},
		{1, 0.1, 0.7, 1},
	},
	quaver = {
		{1, 1, 0.71, 1},
		{1, 0.91, 0.44, 1},
		{0.38, 0.96, 0.47, 1},
		{0.25, 0.7, 0.75, 1},
		{0.72, 0.46, 0.65, 1},
	},
	bmsrank = {
		{0.6, 0.8, 1, 1},
		{0.95, 0.796, 0.188, 1},
		{1, 0.69, 0.24, 1},
		{1, 0.5, 0.24, 1},
	},
}

ScoringUtils.gradeColors = {
	sphere = {
		["-"] = {1, 1, 1, 1},
	},
	osuod = {
		SS = {0.6, 0.8, 1, 1},
		S = {0.95, 0.796, 0.188, 1},
		A = {0.07, 0.8, 0.56, 1},
		B = {0.1, 0.39, 1, 1},
		C = {0.42, 0.48, 0.51, 1},
		D = {0.51, 0.37, 0, 1},
	},
	etternaj = {
		AAAAA = {1, 1, 1, 1},
		AAAA = {0.6, 0.8, 1, 1},
		AAA = {0.95, 0.796, 0.188, 1},
		AA = {0.07, 0.8, 0.56, 1},
		A = {0, 0.7, 0.32, 1},
		B = {0.1, 0.7, 1, 1},
		C = {1, 0.1, 0.7, 1},
		F = {0.51, 0.37, 0, 1},
	},
	quaver = {
		X = {0.6, 0.8, 1, 1},
		S = {0.95, 0.796, 0.188, 1},
		A = {0.95, 0.796, 0.188, 1},
		B = {0.07, 0.8, 0.56, 1},
		C = {0.1, 0.39, 1, 1},
		D = {0.42, 0.48, 0.51, 1},
		F = {0.51, 0.37, 0, 1},
	},
	bmsrank = {
		AAA = {0.95, 0.796, 0.188, 1},
		AA = {0.07, 0.8, 0.56, 1},
		A = {0, 0.7, 0.32, 1},
		B = {0.1, 0.7, 1, 1},
		C = {1, 0.1, 0.7, 1},
		E = {1, 0.1, 0.7, 1},
		F = {0.51, 0.37, 0, 1},
	},
}

local F = {0.51, 0.37, 0, 1}

---@param timings_name sea.TimingsName
---@param grade string
---@return gui.Color
function ScoringUtils.getGradeColor(timings_name, grade)
	local ss = ScoringUtils.gradeColors[timings_name]

	if not ss then
		return F
	end

	return ss[grade] or F
end

return ScoringUtils
