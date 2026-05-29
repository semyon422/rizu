--- Score submission chart response generator.
---
--- Generates the pipe-delimited chart response that the osu! client displays
--- after a successful score submission. Contains three sections:
--- 1. Beatmap info (ID, set ID, playcount, passcount, approved date)
--- 2. Beatmap ranking (rank, score, maxCombo, accuracy, pp before/after)
--- 3. Overall ranking (rank, rscore, tscore, maxCombo, accuracy, pp before/after)

--- Chart entry data.
---@class bancho.score.ChartEntry
---@field name string entry name (e.g. "rank")
---@field before number|nil previous value
---@field after number after value

--- Chart generation context.
---@class bancho.score.ChartContext
---@field score_id integer new score ID
---@field bmap table beatmap data
---@field score table score data (with pp, accuracy, etc.)
---@field prev_best table|nil previous best score on this map (or nil)
---@field prev_stats table|nil previous overall stats (or nil)
---@field current_stats table current overall stats after update
---@field domain string server domain
---@field achievements string achievement string (may be empty)

--- Format a number for chart output (round floats to 2 decimals).
---@param v number|nil
---@return string
local function fmt(v)
	if v == nil then
		return ""
	end
	-- If it's an integer, output without decimals
	if v == math.floor(v) then
		return tostring(math.floor(v))
	end
	return string.format("%.2f", v)
end

--- Format a single chart entry as "nameBefore:value|nameAfter:value".
--- Nil values produce empty strings.
---@param name string
---@param before number|nil
---@param after number
---@return string
local function format_entry(name, before, after)
	return string.format(
		"%sBefore:%s|%sAfter:%s",
		name,
		before ~= nil and fmt(before) or "",
		name,
		fmt(after)
	)
end

--- Generate the score submission chart response.
---
--- Returns the pipe-delimited chart string that the osu! client parses
--- to display the submission result screen.
---
---@param ctx bancho.score.ChartContext
---@return string chart_response
local function generate(ctx)
	local entries = {}

	-- Beatmap info section
	table.insert(entries, string.format("beatmapId:%d", ctx.bmap.id or 0))
	table.insert(entries, string.format("beatmapSetId:%d", ctx.bmap.set_id or 0))
	table.insert(entries, string.format("beatmapPlaycount:%s", fmt(ctx.bmap.plays)))
	table.insert(entries, string.format("beatmapPasscount:%s", fmt(ctx.bmap.passes)))
	table.insert(entries, string.format("approvedDate:%s", fmt(ctx.bmap.last_update or 0)))

	-- Section separator
	table.insert(entries, "")

	-- Beatmap ranking chart
	table.insert(entries, "chartId:beatmap")
	table.insert(entries, string.format("chartUrl:https://%s/p/%d", ctx.domain, ctx.bmap.set_id or 0))
	table.insert(entries, "chartName:Beatmap Ranking")

	local prev_best = ctx.prev_best
	local score = ctx.score

	table.insert(entries, format_entry("rank",
		prev_best and prev_best.rank,
		score.rank or 0
	))
	table.insert(entries, format_entry("rankedScore",
		prev_best and prev_best.score,
		score.score or 0
	))
	table.insert(entries, format_entry("totalScore",
		prev_best and prev_best.score,
		score.score or 0
	))
	table.insert(entries, format_entry("maxCombo",
		prev_best and prev_best.max_combo,
		score.max_combo or 0
	))
	table.insert(entries, format_entry("accuracy",
		prev_best and prev_best.accuracy,
		score.accuracy or 0
	))
	table.insert(entries, format_entry("pp",
		prev_best and prev_best.pp,
		score.pp or 0
	))

	table.insert(entries, string.format("onlineScoreId:%d", ctx.score_id or 0))

	-- Section separator
	table.insert(entries, "")

	-- Overall ranking chart
	table.insert(entries, "chartId:overall")
	table.insert(entries, string.format("chartUrl:https://%s/u/%d", ctx.domain, ctx.score.player_id or 0))
	table.insert(entries, "chartName:Overall Ranking")

	local prev_stats = ctx.prev_stats
	local current_stats = ctx.current_stats or {}

	table.insert(entries, format_entry("rank",
		prev_stats and prev_stats.rank,
		current_stats.rank or 0
	))
	table.insert(entries, format_entry("rankedScore",
		prev_stats and prev_stats.rscore,
		current_stats.rscore or 0
	))
	table.insert(entries, format_entry("totalScore",
		prev_stats and prev_stats.tscore,
		current_stats.tscore or 0
	))
	table.insert(entries, format_entry("maxCombo",
		prev_stats and prev_stats.max_combo,
		current_stats.max_combo or 0
	))
	table.insert(entries, format_entry("accuracy",
		prev_stats and prev_stats.accuracy,
		current_stats.accuracy or 0
	))
	table.insert(entries, format_entry("pp",
		prev_stats and prev_stats.pp,
		current_stats.pp or 0
	))

	-- Achievements
	table.insert(entries, string.format("achievements-new:%s", ctx.achievements or ""))

	return table.concat(entries, "|")
end

return {
	generate = generate,
}
