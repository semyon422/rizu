--- Tests for bancho score Chart module.

local Chart = require("bancho.score.Chart")

local test = {}

function test.generate_basic_chart(t)
	local ctx = {
		score_id = 42,
		bmap = {
			id = 100,
			set_id = 200,
			plays = 1000,
			passes = 800,
			last_update = 1700000000,
		},
		score = {
			player_id = 1,
			rank = 5,
			score = 123456,
			max_combo = 500,
			accuracy = 95.5,
			pp = 150.25,
		},
		prev_best = nil,
		prev_stats = nil,
		current_stats = {
			rank = 100,
			rscore = 500000,
			tscore = 1000000,
			max_combo = 500,
			accuracy = 92.3,
			pp = 2000,
		},
		domain = "test.su",
		achievements = "",
	}

	local result = Chart.generate(ctx)

	-- Verify structure
	t:eq(result:find("beatmapId:100"), 1)
	t:ne(result:find("beatmapSetId:200"), nil)
	t:ne(result:find("beatmapPlaycount:1000"), nil)
	t:ne(result:find("beatmapPasscount:800"), nil)
	t:ne(result:find("chartId:beatmap"), nil)
	t:ne(result:find("chartName:Beatmap Ranking"), nil)
	t:ne(result:find("chartId:overall"), nil)
	t:ne(result:find("chartName:Overall Ranking"), nil)
	t:ne(result:find("onlineScoreId:42"), nil)
	t:ne(result:find("achievements-new:", 1, true), nil)
	t:ne(result:find("chartUrl:https://test.su/p/200"), nil)
	t:ne(result:find("chartUrl:https://test.su/u/1"), nil)

	-- Verify before/after for nil prev_best
	t:ne(result:find("rankBefore:|rankAfter:5"), nil)
end

function test.generate_chart_with_prev_best(t)
	local ctx = {
		score_id = 99,
		bmap = {
			id = 100,
			set_id = 200,
			plays = 1000,
			passes = 800,
			last_update = 1700000000,
		},
		score = {
			player_id = 1,
			rank = 3,
			score = 200000,
			max_combo = 600,
			accuracy = 98.0,
			pp = 200.0,
		},
		prev_best = {
			rank = 5,
			score = 150000,
			max_combo = 500,
			accuracy = 90.0,
			pp = 150.0,
		},
		prev_stats = {
			rank = 200,
			rscore = 400000,
			tscore = 900000,
			max_combo = 500,
			accuracy = 91.0,
			pp = 1800,
		},
		current_stats = {
			rank = 180,
			rscore = 600000,
			tscore = 1100000,
			max_combo = 600,
			accuracy = 91.5,
			pp = 2000,
		},
		domain = "test.su",
		achievements = "",
	}

	local result = Chart.generate(ctx)

	-- Verify before/after entries exist
	t:ne(result:find("rankBefore:5|rankAfter:3"), nil)
	t:ne(result:find("rankedScoreBefore:150000|rankedScoreAfter:200000"), nil)
	t:ne(result:find("maxComboBefore:500|maxComboAfter:600"), nil)
	-- Check overall stats
	t:ne(result:find("rankBefore:200|rankAfter:180"), nil)
end

function test.generate_chart_no_prev_values(t)
	local ctx = {
		score_id = 1,
		bmap = {
			id = 1,
			set_id = 1,
			plays = 0,
			passes = 0,
			last_update = 0,
		},
		score = {
			player_id = 1,
			rank = 1,
			score = 100000,
			max_combo = 100,
			accuracy = 100.0,
			pp = 50.0,
		},
		prev_best = nil,
		prev_stats = nil,
		current_stats = {
			rank = 1,
			rscore = 100000,
			tscore = 100000,
			max_combo = 100,
			accuracy = 100.0,
			pp = 50.0,
		},
		domain = "test.su",
		achievements = "",
	}

	local result = Chart.generate(ctx)

	-- Nil before values should produce empty strings in the output
	t:ne(result:find("rankBefore:|rankAfter:1"), nil)
end

function test.generate_chart_with_achievements(t)
	local ctx = {
		score_id = 1,
		bmap = {
			id = 1,
			set_id = 1,
			plays = 0,
			passes = 0,
			last_update = 0,
		},
		score = {
			player_id = 1,
			rank = 1,
			score = 100000,
			max_combo = 100,
			accuracy = 100.0,
			pp = 50.0,
		},
		prev_best = nil,
		prev_stats = nil,
		current_stats = {},
		domain = "test.su",
		achievements = "file.png+Name+Description",
	}

	local result = Chart.generate(ctx)
	t:ne(result:find("achievements-new:file.png+Name+Description", 1, true), nil)
end

function test.generate_chart_float_accuracy(t)
	local ctx = {
		score_id = 1,
		bmap = {
			id = 1,
			set_id = 1,
			plays = 0,
			passes = 0,
			last_update = 0,
		},
		score = {
			player_id = 1,
			rank = 1,
			score = 100000,
			max_combo = 100,
			accuracy = 92.345678,
			pp = 123.456,
		},
		prev_best = nil,
		prev_stats = nil,
		current_stats = {},
		domain = "test.su",
		achievements = "",
	}

	local result = Chart.generate(ctx)
	-- Floats should be rounded to 2 decimals
	t:ne(result:find("accuracyAfter:92.35"), nil)
end

return test
