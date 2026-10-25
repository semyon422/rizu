local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local Scoring = require("rizu.engine.scoring.Scoring")

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

---@param token string
---@param chart_timings sea.Timings? What "auto" stands for.
---@return rizu.engine.scoring.Scoring? scoring nil for invalid tokens, and for "auto" without chart timings.
function StoredAccuracies.getScoring(token, chart_timings)
	local timings, subtimings ---@type sea.Timings?, sea.Subtimings?
	if token == "auto" then
		timings = chart_timings
	else
		timings, subtimings = StoredAccuracies.decode(token)
	end
	if not timings then
		return
	end
	local scoring = Scoring(timings, subtimings)
	if scoring:createScoreSystems() then
		return scoring
	end
end

---Valid tokens of a setting value, without repeats.
---@param s string
---@return string[]
function StoredAccuracies.parse(s)
	local tokens = {}
	---@type {[string]: true}
	local seen = {}
	for token in s:gmatch("[^,%s]+") do
		local scoring = token ~= "auto" and StoredAccuracies.getScoring(token)
		-- Normalscore needs no row: chartplays.accuracy holds it.
		local valid = token == "auto" or scoring and not scoring:isNormalscore()
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
		local scoring = StoredAccuracies.getScoring(token, chart_timings)
		local source = scoring and not scoring:isNormalscore() and scoring:getAccuracySource(score_engine)
		if source then
			---@cast scoring -?
			local timings, subtimings = scoring:encode()
			local key = timings .. ":" .. subtimings
			if not seen[key] then
				seen[key] = true
				table.insert(rows, {timings = timings, subtimings = subtimings, accuracy = source:getAccuracy()})
			end
		end
	end
	return rows
end

return StoredAccuracies
