local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local IAccuracySource = require("rizu.engine.ScoreEngine.IAccuracySource")
local ScoreEngineFactory = require("rizu.engine.ScoreEngine.ScoreEngineFactory")

---Accuracies stored with every score besides normalscore, which chartplays.accuracy holds.
---The setting lists them as tokens, such as "auto,osuod:9:1,etternaj:4":
---"auto" is the chart's own timings, the others are "name[:value[:osu score version]]".
local StoredAccuracies = {}

---@class rizu.engine.ScoreEngine.StoredAccuracies.Row
---@field timings integer Encoded sea.Timings of the system.
---@field subtimings integer Encoded sea.Subtimings, 0 for none.
---@field accuracy number

---@param token string
---@return sea.Timings
---@return sea.Subtimings?
local function decode(token)
	local name, value, version = token:match("^(%a+):?([%d.]*):?(%d*)$")
	local timings = Timings(assert(name), tonumber(value))
	return timings, version ~= "" and Subtimings("scorev", tonumber(version)) or nil
end

---@param token string
---@return sea.Timings? timings nil for "auto" and for invalid tokens.
---@return sea.Subtimings?
function StoredAccuracies.decode(token)
	local ok, timings, subtimings = pcall(decode, token)
	if ok then
		return timings, subtimings
	end
end

---@param timings sea.Timings
---@param subtimings sea.Subtimings?
---@return rizu.ScoreSystem[]? systems Those with accuracy, nil when the pair is invalid or none has it.
local function getAccuracySystems(timings, subtimings)
	local systems = ScoreEngineFactory:get(timings, subtimings)
	if not systems then
		return
	end
	---@type rizu.ScoreSystem[]
	local accuracy_systems = {}
	for _, system in ipairs(systems) do
		if IAccuracySource * system then
			table.insert(accuracy_systems, system)
		end
	end
	return accuracy_systems[1] and accuracy_systems or nil
end

---@param timings sea.Timings
---@param subtimings sea.Subtimings?
---@param accuracy number As stored.
---@return string? text Such as "98.50%", nil for timings without accuracy.
function StoredAccuracies.format(timings, subtimings, accuracy)
	local systems = getAccuracySystems(timings, subtimings)
	local system = systems and systems[1] --[[@as rizu.IAccuracySource?]]
	return system and system.accuracy_format:format(accuracy * system.accuracy_multiplier)
end

---Valid tokens of a setting value, without repeats.
---@param s string
---@return string[]
function StoredAccuracies.parse(s)
	local tokens = {}
	---@type {[string]: true}
	local seen = {}
	for token in s:gmatch("[^,%s]+") do
		local timings, subtimings = StoredAccuracies.decode(token)
		local valid = token == "auto" or timings and getAccuracySystems(timings, subtimings)
		if valid and not seen[token] then
			seen[token] = true
			table.insert(tokens, token)
		end
	end
	return tokens
end

---Scores the events the engine received with every system of the tokens.
---@param score_engine rizu.ScoreEngine
---@param tokens string[]
---@param chart_timings sea.Timings? What "auto" stands for.
---@return rizu.engine.ScoreEngine.StoredAccuracies.Row[]
function StoredAccuracies.compute(score_engine, tokens, chart_timings)
	local rows = {}
	---@type {[string]: true}
	local seen = {}
	for _, token in ipairs(tokens) do
		local timings, subtimings = StoredAccuracies.decode(token)
		if token == "auto" then
			timings, subtimings = chart_timings, nil
		end
		for _, system in ipairs(timings and getAccuracySystems(timings, subtimings) or {}) do
			system = score_engine:addScoreSystem(system)
			---@type rizu.engine.ScoreEngine.StoredAccuracies.Row
			local row = {
				timings = assert(system.timings):encode(),
				subtimings = system.subtimings and system.subtimings:encode() or 0,
				accuracy = (system --[[@as rizu.IAccuracySource]]):getAccuracy(),
			}
			local key = row.timings .. ":" .. row.subtimings
			if not seen[key] then
				seen[key] = true
				table.insert(rows, row)
			end
		end
	end
	return rows
end

return StoredAccuracies
