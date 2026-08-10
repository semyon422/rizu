local table_util = require("table_util")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local Leaderboards = require("sea.leaderboards.Leaderboards")
local Leaderboard = require("sea.leaderboards.Leaderboard")
local TotalRating = require("sea.leaderboards.TotalRating")
local LeaderboardDifftable = require("sea.leaderboards.LeaderboardDifftable")
local LeaderboardsRepo = require("sea.leaderboards.repos.LeaderboardsRepo")
local User = require("sea.access.User")
local UserRole = require("sea.access.UserRole")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local Healths = require("sea.chart.Healths")

local test = {}

local function create_test_ctx()
	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:open()

	-- db.orm:debug(true)

	local models = db.models

	local leaderboards_repo = LeaderboardsRepo(models)

	local user = User()
	user.id = 1
	user.user_roles = {UserRole("admin", 0)}

	local leaderboard = Leaderboard()
	leaderboard.name = "Leaderboard 1"

	local leaderboards = Leaderboards(leaderboards_repo)
	local leaderboard, err = assert(leaderboards:create(user, leaderboard))
	leaderboard = leaderboards:getLeaderboard(leaderboard.id)

	assert(leaderboard, err)

	return {
		db = db,
		leaderboards_repo = leaderboards_repo,
		user = user,
		leaderboard = leaderboard,
		leaderboards = leaderboards,
	}
end

---@param ctx {leaderboards: sea.Leaderboards, leaderboard: sea.Leaderboard}
local function lb_update_select(ctx)
	ctx.leaderboards:update(ctx.user, ctx.leaderboard.id, ctx.leaderboard)
	ctx.leaderboard = assert(ctx.leaderboards:getLeaderboard(ctx.leaderboard.id))
end

---@param ctx {db: sea.ServerSqliteDatabase, user: sea.User}
---@param values {[string]: any}
local function create_chartplay(ctx, values)
	---@type sea.Chartplay
	local chartplay = table_util.copy(values)
	chartplay.user_id = values.user_id or ctx.user.id
	chartplay.hash = values.hash or ""
	chartplay.index = 1
	chartplay.modifiers = values.modifiers or {}
	chartplay.rate = values.rate or 1
	chartplay.mode = values.mode or "mania"
	chartplay.rating = values.rating or 0
	chartplay.not_perfect_count = values.not_perfect_count or 0
	chartplay.timings = values.timings
	chartplay.subtimings = values.subtimings
	chartplay.submitted_at = values.submitted_at or 0
	chartplay.computed_at = values.computed_at or 0
	chartplay.created_at = values.created_at or 0
	chartplay.compute_state = "valid"
	chartplay.replay_hash = ("%032x"):format(ctx.db.models.chartplays:count() + 1)
	chartplay.pause_count = chartplay.pause_count or 0
	chartplay.nearest = not not chartplay.nearest
	chartplay.tap_only = not not chartplay.tap_only
	chartplay.custom = not not chartplay.custom
	chartplay.const = not not chartplay.const
	chartplay.rate_type = "linear"
	chartplay.judges = {}
	chartplay.accuracy = chartplay.accuracy or 0
	chartplay.max_combo = chartplay.max_combo or 0
	chartplay.miss_count = chartplay.miss_count or 0
	chartplay.rating_pp = chartplay.rating_pp or 0
	chartplay.rating_msd = chartplay.rating_msd or 0
	if values.pass ~= nil then
		chartplay.pass = values.pass
	else
		chartplay.pass = false
	end
	return ctx.db.models.chartplays:create(chartplay)
end

---@param ctx {db: sea.ServerSqliteDatabase, user: sea.User}
---@param values {[string]: any}
local function create_chartdiff(ctx, values)
	---@type sea.Chartdiff
	local chartdiff = table_util.copy(values)
	chartdiff.created_at = chartdiff.created_at or 0
	chartdiff.computed_at = chartdiff.computed_at or 0
	chartdiff.hash = chartdiff.hash or "00000000000000000000000000000000"
	chartdiff.index = chartdiff.index or 1
	chartdiff.modifiers = chartdiff.modifiers or {}
	chartdiff.rate = chartdiff.rate or 1
	chartdiff.mode = chartdiff.mode or "mania"
	chartdiff.inputmode = chartdiff.inputmode or "4key"
	chartdiff.duration = chartdiff.duration or 0
	chartdiff.start_time = chartdiff.start_time or 0
	chartdiff.notes_count = chartdiff.notes_count or 0
	chartdiff.judges_count = chartdiff.judges_count or 0
	chartdiff.note_types_count = chartdiff.note_types_count or {}
	chartdiff.density_data = chartdiff.density_data or {}
	chartdiff.sv_data = chartdiff.sv_data or {}
	chartdiff.enps_diff = chartdiff.enps_diff or 0
	chartdiff.osu_diff = chartdiff.osu_diff or 0
	chartdiff.msd_diff = chartdiff.msd_diff or 0
	chartdiff.msd_diff_data = chartdiff.msd_diff_data or {}
	chartdiff.msd_diff_rates = chartdiff.msd_diff_rates or {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	chartdiff.user_diff = chartdiff.user_diff or 0
	chartdiff.user_diff_data = chartdiff.user_diff_data or ""
	chartdiff.notes_preview = chartdiff.notes_preview or ""
	return ctx.db.models.chartdiffs:create(chartdiff)
end

---@param t testing.T
function test.best_score_filter(t)
	local ctx = create_test_ctx()

	create_chartplay(ctx, {rating = 1, hash = "1"})
	create_chartplay(ctx, {rating = 2, hash = "1"})
	create_chartplay(ctx, {rating = 3, hash = "2"})
	create_chartplay(ctx, {rating = 4, hash = "2"})

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 2) then
		t:eq(chartplays[1].rating, 4)
		t:eq(chartplays[2].rating, 2)
	end
end

---@param t testing.T
function test.user_filter(t)
	local ctx = create_test_ctx()

	create_chartplay(ctx, {rating = 1, user_id = 1})
	create_chartplay(ctx, {rating = 2, user_id = 2})

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, 1)

	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 1)
	end

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, 2)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 2)
	end
end

---@param t testing.T
function test.nearest_filter_single(t)
	local ctx = create_test_ctx()

	create_chartplay(ctx, {rating = 1, nearest = true, hash = ""})
	create_chartplay(ctx, {rating = 2, nearest = false, hash = ""})

	ctx.leaderboard.nearest = "any"
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 1)

	ctx.leaderboard.nearest = "disabled"
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 2)
	end

	ctx.leaderboard.nearest = "enabled"
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 1)
	end
end

---@param t testing.T
function test.nearest_filter_multiple(t)
	local ctx = create_test_ctx()

	create_chartplay(ctx, {rating = 1, nearest = true, hash = "1"})
	create_chartplay(ctx, {rating = 2, nearest = false, hash = "2"})

	ctx.leaderboard.nearest = "any"
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 2)

	ctx.leaderboard.nearest = "disabled"
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 2)
	end

	ctx.leaderboard.nearest = "enabled"
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 1)
	end
end

---@param t testing.T
function test.pass_filter(t)
	local ctx = create_test_ctx()

	local _chartplays = {
		create_chartplay(ctx, {rating = 1, pass = true}),
		create_chartplay(ctx, {rating = 2, pass = false}),
	}

	t:eq(#_chartplays, 2)

	for _, c in ipairs(_chartplays) do
		ctx.leaderboard.pass = c.pass
		lb_update_select(ctx)

		local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
		if t:eq(#chartplays, 1) then
			t:eq(chartplays[1].rating, c.rating)
		end
	end
end

---@param t testing.T
function test.judges_result_filter(t)
	local ctx = create_test_ctx()

	local _chartplays = {
		create_chartplay(ctx, {rating = 1, miss_count = 0, not_perfect_count = 0}),
		create_chartplay(ctx, {rating = 2, miss_count = 0, not_perfect_count = 1}),
		create_chartplay(ctx, {rating = 3, miss_count = 1, not_perfect_count = 1}),
	}

	ctx.leaderboard.judges = "pfc"
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 1)
	end

	ctx.leaderboard.judges = "fc"
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 2)
	end

	ctx.leaderboard.judges = "any"
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 3)
	end
end

---@param t testing.T
function test.custom_filter(t)
	local ctx = create_test_ctx()

	create_chartplay(ctx, {rating = 1, custom = false, hash = "1"})
	create_chartplay(ctx, {rating = 2, custom = true, hash = "2"})

	ctx.leaderboard.allow_custom = true
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 2)

	ctx.leaderboard.allow_custom = false
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 1)
	end
end

---@param t testing.T
function test.pause_filter(t)
	local ctx = create_test_ctx()

	create_chartplay(ctx, {rating = 1, pause_count = 0, hash = "1"})
	create_chartplay(ctx, {rating = 2, pause_count = 1, hash = "2"})

	ctx.leaderboard.allow_pause = true
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 2)

	ctx.leaderboard.allow_pause = false
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 1)
	end
end

---@param t testing.T
function test.reorder_filter(t)
	local ctx = create_test_ctx()

	create_chartplay(ctx, {rating = 1, columns_order = {}, hash = "1"})
	create_chartplay(ctx, {rating = 2, columns_order = {4, 3, 2, 1}, hash = "2"})

	ctx.leaderboard.allow_reorder = true
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 2)

	ctx.leaderboard.allow_reorder = false
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 1)
	end
end

---@param t testing.T
function test.modifiers_filter(t)
	local ctx = create_test_ctx()

	create_chartplay(ctx, {rating = 1, modifiers = {}, hash = "1"})
	create_chartplay(ctx, {rating = 2, modifiers = {"any data here"}, hash = "2"})

	ctx.leaderboard.allow_modifiers = true
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 2)

	ctx.leaderboard.allow_modifiers = false
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 1)
	end
end

---@param t testing.T
function test.tap_only_filter(t)
	local ctx = create_test_ctx()

	create_chartplay(ctx, {rating = 1, tap_only = false, hash = "1"})
	create_chartplay(ctx, {rating = 2, tap_only = true, hash = "2"})

	ctx.leaderboard.allow_tap_only = true
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 2)

	ctx.leaderboard.allow_tap_only = false
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 1)
	end
end

---@param t testing.T
function test.free_timings_filter(t)
	local ctx = create_test_ctx()

	ctx.db.models.chartmetas:create({
		format = "osu",
		inputmode = "4key",
		timings = Timings("simple", 0.1),
		hash = "",
		index = 1,
		created_at = 0,
		computed_at = 0,
	})

	create_chartplay(ctx, {rating = 1, timings = Timings("simple", 0.1)})
	create_chartplay(ctx, {rating = 2, timings = Timings("osuod", 8), subtimings = Subtimings("scorev", 1)})

	ctx.leaderboard.allow_free_timings = true
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 2)
	end

	ctx.leaderboard.allow_free_timings = false
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 1)
	end
end

---@param t testing.T
function test.free_timings_filter_specific(t)
	local ctx = create_test_ctx()

	ctx.db.models.chartmetas:create({
		format = "osu",
		inputmode = "4key",
		timings = Timings("simple", 0.2),
		hash = "",
		index = 1,
		created_at = 0,
		computed_at = 0,
	})

	create_chartplay(ctx, {rating = 1, timings = Timings("simple", 0.1)})
	create_chartplay(ctx, {rating = 2, timings = Timings("osuod", 8), subtimings = Subtimings("scorev", 1)})

	ctx.leaderboard.allow_free_timings = true
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 2)
	end

	ctx.leaderboard.allow_free_timings = false
	ctx.leaderboard.timings = Timings("simple", 0.1)
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 1)
	end
end

---@param t testing.T
function test.free_timings_filter_undefined_both(t)
	-- impossible case because timings should be set
	-- there is no default timings for timings-less formats

	local ctx = create_test_ctx()

	ctx.db.models.chartmetas:create({
		format = "osu",
		inputmode = "4key",
		hash = "",
		index = 1,
		created_at = 0,
		computed_at = 0,
	})

	create_chartplay(ctx, {rating = 1})

	ctx.leaderboard.allow_free_timings = true
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 1)

	ctx.leaderboard.allow_free_timings = false
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 1)
end

---@param t testing.T
function test.free_timings_filter_undefined_chart(t)
	local ctx = create_test_ctx()

	ctx.db.models.chartmetas:create({
		format = "osu",
		inputmode = "4key",
		hash = "",
		index = 1,
		created_at = 0,
		computed_at = 0,
	})

	create_chartplay(ctx, {
		rating = 1,
		timings = Timings("osuod", 10),
	})

	ctx.leaderboard.allow_free_timings = true
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 1)

	ctx.leaderboard.allow_free_timings = false
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 0)
end

---@param t testing.T
function test.free_timings_filter_undefined_score(t)
	local ctx = create_test_ctx()

	ctx.db.models.chartmetas:create({
		format = "osu",
		inputmode = "4key",
		timings = Timings("osuod", 10),
		hash = "",
		index = 1,
		created_at = 0,
		computed_at = 0,
	})

	create_chartplay(ctx, {
		rating = 1,
	})

	ctx.leaderboard.allow_free_timings = true
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 1)

	ctx.leaderboard.allow_free_timings = false
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 1)
end

---@param t testing.T
function test.free_healths_filter(t)
	local ctx = create_test_ctx()

	ctx.db.models.chartmetas:create({
		format = "osu",
		inputmode = "4key",
		healths = Healths("simple", 10),
		hash = "",
		index = 1,
		created_at = 0,
		computed_at = 0,
	})

	create_chartplay(ctx, {rating = 1, healths = Healths("simple", 10)})
	create_chartplay(ctx, {rating = 2, healths = Healths("simple", 20)})

	ctx.leaderboard.allow_free_healths = true
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 2)
	end

	ctx.leaderboard.allow_free_healths = false
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 1)
	end
end

---@param t testing.T
function test.rate_filter(t)
	local ctx = create_test_ctx()

	ctx.db.models.chartmetas:create({
		format = "osu",
		inputmode = "4key",
		hash = "",
		index = 1,
		created_at = 0,
		computed_at = 0,
	})

	create_chartplay(ctx, {rating = 1, rate = 1.0})
	create_chartplay(ctx, {rating = 2, rate = 1.1})
	create_chartplay(ctx, {rating = 3, rate = 1.2})

	ctx.leaderboard.rate = "any"
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 3)
	end

	ctx.leaderboard.rate = {1, 1.1}
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 2)
	end

	ctx.leaderboard.rate = {min = 0.9, max = 1.15}
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 2)
	end
end

---@param t testing.T
function test.chartmeta_inputmode_filter(t)
	local ctx = create_test_ctx()

	ctx.db.models.chartmetas:create({
		format = "osu",
		hash = "1",
		index = 1,
		inputmode = "4key",
		created_at = 0,
		computed_at = 0,
	})

	ctx.db.models.chartmetas:create({
		format = "osu",
		hash = "2",
		index = 1,
		inputmode = "7key",
		created_at = 0,
		computed_at = 0,
	})

	ctx.db.models.chartmetas:create({
		format = "osu",
		hash = "3",
		index = 1,
		inputmode = "10key",
		created_at = 0,
		computed_at = 0,
	})

	create_chartplay(ctx, {rating = 1, hash = "1"})
	create_chartplay(ctx, {rating = 2, hash = "2"})
	create_chartplay(ctx, {rating = 3, hash = "3"})

	ctx.leaderboard.chartmeta_inputmode = {}
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 3)

	ctx.leaderboard.chartmeta_inputmode = {"4key", "7key"}
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 2)
end

---@param t testing.T
function test.chartdiff_inputmode_filter(t)
	local ctx = create_test_ctx()

	create_chartdiff(ctx, {
		hash = "1",
		inputmode = "4key",
	})

	create_chartdiff(ctx, {
		hash = "2",
		inputmode = "7key",
	})

	create_chartdiff(ctx, {
		hash = "3",
		inputmode = "10key",
	})

	create_chartplay(ctx, {rating = 1, hash = "1"})
	create_chartplay(ctx, {rating = 2, hash = "2"})
	create_chartplay(ctx, {rating = 3, hash = "3"})

	ctx.leaderboard.chartdiff_inputmode = {}
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 3)

	ctx.leaderboard.chartdiff_inputmode = {"4key", "7key"}
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	t:eq(#chartplays, 2)
end

---@param t testing.T
function test.difftable_filter_single(t)
	local ctx = create_test_ctx()

	local models = ctx.db.models

	create_chartplay(ctx, {rating = 1, hash = "1"})
	create_chartplay(ctx, {rating = 2, hash = "2"})

	local difftable = models.difftables:create({
		name = "Ranked list 1",
		description = "",
		symbol = "x",
		created_at = 0,
	})

	models.difftable_chartmetas:create({
		difftable_id = difftable.id,
		user_id = 1,
		hash = "2",
		index = 1,
		level = 0,
		created_at = 0,
		updated_at = 0,
		is_deleted = false,
		change_index = 1,
	})

	ctx.leaderboard.leaderboard_difftables = {{id = 1, leaderboard_id = 1, difftable_id = difftable.id}}
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].rating, 2)
	end
end

---@param t testing.T
function test.difftable_filter_multiple(t)
	local ctx = create_test_ctx()

	local models = ctx.db.models

	create_chartplay(ctx, {rating = 1})

	local difftable_1 = models.difftables:create({
		name = "Ranked list 1",
		description = "",
		symbol = "x",
		created_at = 0,
	})
	local difftable_2 = models.difftables:create({
		name = "Ranked list 2",
		description = "",
		symbol = "y",
		created_at = 0,
	})

	models.difftable_chartmetas:create({
		difftable_id = difftable_1.id,
		user_id = 1,
		hash = "",
		index = 1,
		level = 1,
		created_at = 0,
		updated_at = 0,
		is_deleted = false,
		change_index = 1,
	})

	models.difftable_chartmetas:create({
		difftable_id = difftable_2.id,
		user_id = 1,
		hash = "",
		index = 1,
		level = 2,
		created_at = 0,
		updated_at = 0,
		is_deleted = false,
		change_index = 1,
	})

	ctx.leaderboard.leaderboard_difftables = {{id = 1, leaderboard_id = 1, difftable_id = difftable_1.id}}
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].difftable_id, 1)
		t:eq(chartplays[1].difftable_level, 1)
	end

	ctx.leaderboard.leaderboard_difftables = {{id = 1, leaderboard_id = 1, difftable_id = difftable_2.id}}
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 1) then
		t:eq(chartplays[1].difftable_id, 2)
		t:eq(chartplays[1].difftable_level, 2)
	end

	ctx.leaderboard.leaderboard_difftables = {
		{id = 1, leaderboard_id = 1, difftable_id = difftable_1.id},
		{id = 1, leaderboard_id = 1, difftable_id = difftable_2.id},
	}
	lb_update_select(ctx)

	-- local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	-- if t:eq(#chartplays, 1) then
	-- 	t:eq(chartplays[1].difftable_id, 2)
	-- 	t:eq(chartplays[1].difftable_level, 2)
	-- end
end

---@param t testing.T
function test.rating_calc_filter(t)
	local ctx = create_test_ctx()

	create_chartplay(ctx, {rating = 1, rating_pp = 2, hash = "1"})
	create_chartplay(ctx, {rating = 2, rating_pp = 1, hash = "2"})

	ctx.leaderboard.rating_calc = "enps"
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 2) then
		t:eq(chartplays[1].rating, 2)
		t:eq(chartplays[1].rating_pp, 1)
	end

	ctx.leaderboard.rating_calc = "pp"
	lb_update_select(ctx)

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, ctx.user.id)
	if t:eq(#chartplays, 2) then
		t:eq(chartplays[1].rating, 1)
		t:eq(chartplays[1].rating_pp, 2)
	end
end

--------------------------------------------------------------------------------

---@param t testing.T
function test.check_chartplay(t)
	local ctx = create_test_ctx()

	local cp1 = create_chartplay(ctx, {rating = 1, nearest = true, hash = ""})
	local cp2 = create_chartplay(ctx, {rating = 2, nearest = false, hash = ""})

	ctx.leaderboard.nearest = "any"
	lb_update_select(ctx)

	t:assert(ctx.leaderboards_repo:checkChartplay(ctx.leaderboard, cp1))
	t:assert(ctx.leaderboards_repo:checkChartplay(ctx.leaderboard, cp2))

	ctx.leaderboard.nearest = "disabled"
	lb_update_select(ctx)

	t:assert(not ctx.leaderboards_repo:checkChartplay(ctx.leaderboard, cp1))
	t:assert(ctx.leaderboards_repo:checkChartplay(ctx.leaderboard, cp2))

	ctx.leaderboard.nearest = "enabled"
	lb_update_select(ctx)

	t:assert(ctx.leaderboards_repo:checkChartplay(ctx.leaderboard, cp1))
	t:assert(not ctx.leaderboards_repo:checkChartplay(ctx.leaderboard, cp2))
end

---@param t testing.T
function test.total_rating(t)
	local ctx = create_test_ctx()

	local cp1 = create_chartplay(ctx, {rating = 1, hash = "1"})
	local cp2 = create_chartplay(ctx, {rating = 2, hash = "2"})

	ctx.leaderboards.total_rating.avg_count = 10

	ctx.leaderboards:addChartplay(cp1)

	local lb_user = ctx.db.models.leaderboard_users:find({})
	---@cast lb_user sea.LeaderboardUser

	t:eq(lb_user.total_rating, 0.3)
end

---@param t testing.T
function test.total_rating_same_hash_in_difftable(t)
	local ctx = create_test_ctx()

	local models = ctx.db.models

	local difftable = models.difftables:create({
		name = "Ranked list 1",
		description = "",
		symbol = "x",
		created_at = 0,
	})

	models.difftable_chartmetas:create({
		difftable_id = difftable.id,
		user_id = 1,
		hash = "1",
		index = 1,
		level = 1,
		created_at = 0,
		updated_at = 0,
		is_deleted = false,
		change_index = 1,
	})

	ctx.leaderboard.leaderboard_difftables = {{id = 1, leaderboard_id = 1, difftable_id = difftable.id}}
	lb_update_select(ctx)

	local cp1 = create_chartplay(ctx, {rating = 1, hash = "1"})
	local cp2 = create_chartplay(ctx, {rating = 2, hash = "1"})

	ctx.leaderboards.total_rating.avg_count = 10

	ctx.leaderboards:addChartplay(cp1)

	local lb_user = ctx.db.models.leaderboard_users:find({})
	---@cast lb_user sea.LeaderboardUser

	t:eq(lb_user.total_rating, 0.2)
end

---@param t testing.T
function test.rank(t)
	local ctx = create_test_ctx()

	ctx.leaderboards.total_rating.avg_count = 1

	local cp1 = create_chartplay(ctx, {rating = 1, user_id = 1})
	local cp2 = create_chartplay(ctx, {rating = 2, user_id = 2})

	ctx.leaderboards:addChartplay(cp1)
	ctx.leaderboards:addChartplay(cp2)

	local lb_user_1 = ctx.db.models.leaderboard_users:find({user_id = 1})
	---@cast lb_user_1 sea.LeaderboardUser

	t:eq(lb_user_1.total_rating, 1)
	t:eq(lb_user_1.rank, 2)

	local lb_user_2 = ctx.db.models.leaderboard_users:find({user_id = 2})
	---@cast lb_user_2 sea.LeaderboardUser

	t:eq(lb_user_2.total_rating, 2)
	t:eq(lb_user_2.rank, 1)
end

---@param t testing.T
function test.difftables_create(t)
	local ctx = create_test_ctx()

	local lb_dt_1 = LeaderboardDifftable()
	lb_dt_1.difftable_id = 1
	local lb_dt_2 = LeaderboardDifftable()
	lb_dt_2.difftable_id = 2

	ctx.leaderboard.leaderboard_difftables = {lb_dt_1, lb_dt_2}

	ctx.leaderboards:update(ctx.user, ctx.leaderboard.id, ctx.leaderboard)
	ctx.leaderboard = ctx.leaderboards:getLeaderboard(ctx.leaderboard.id)

	t:eq(#ctx.leaderboard.leaderboard_difftables, 2)
	t:eq(ctx.leaderboard.leaderboard_difftables[1].difftable_id, 1)
	t:eq(ctx.leaderboard.leaderboard_difftables[2].difftable_id, 2)

	local lb_dt_3 = LeaderboardDifftable()
	lb_dt_3.difftable_id = 3

	ctx.leaderboard.leaderboard_difftables = {lb_dt_2, lb_dt_3}

	ctx.leaderboards:update(ctx.user, ctx.leaderboard.id, ctx.leaderboard)
	ctx.leaderboard = ctx.leaderboards:getLeaderboard(ctx.leaderboard.id)

	t:eq(#ctx.leaderboard.leaderboard_difftables, 2)
	t:eq(ctx.leaderboard.leaderboard_difftables[1].difftable_id, 2)
	t:eq(ctx.leaderboard.leaderboard_difftables[2].difftable_id, 3)
end

---@param t testing.T
function test.submit_time(t)
	local ctx = create_test_ctx()

	ctx.leaderboard.starts_at = 5
	ctx.leaderboard.ends_at = 25
	lb_update_select(ctx)

	assert(ctx.leaderboard.starts_at)

	create_chartplay(ctx, {rating = 1, submitted_at = 0})
	create_chartplay(ctx, {rating = 2, submitted_at = 10})
	create_chartplay(ctx, {rating = 3, submitted_at = 20})
	create_chartplay(ctx, {rating = 4, submitted_at = 30})

	local chartplays = ctx.leaderboards_repo:getBestChartplays(ctx.leaderboard, 1)
	t:eq(#chartplays, 1)

	t:eq(chartplays[1].rating, 3)
end

---@param t testing.T
function test.update_histories(t)
	local ctx = create_test_ctx()

	ctx.db.models.leaderboard_users:create({
		leaderboard_id = 1,
		user_id = 1,
		total_rating = 1,
		total_accuracy = 1,
		rank = 1,
		updated_at = 1,
		total_plays = 1,
		ranked_plays = 1,
	})

	ctx.leaderboards:updateHistories(0, ctx.leaderboard)

	local lb_user_his = ctx.db.models.leaderboard_user_histories:find({user_id = 1})
	---@cast lb_user_his sea.LeaderboardUserHistory

	t:eq(#lb_user_his.rank, 90)
	t:eq(lb_user_his:getRank(1), 1)
	t:eq(lb_user_his:getRank(2), 1)
	t:eq(lb_user_his:getRank(3), 1)

	ctx.db.models.leaderboard_users:update({rank = 2})

	ctx.leaderboards:updateHistories(3600 * 24, ctx.leaderboard)

	local lb_user_his = ctx.db.models.leaderboard_user_histories:find({user_id = 1})
	---@cast lb_user_his sea.LeaderboardUserHistory

	t:eq(lb_user_his:getRank(1), 2)
	t:eq(lb_user_his:getRank(2), 1)
	t:eq(lb_user_his:getRank(3), 1)

	ctx.db.models.leaderboard_users:update({rank = 3})

	ctx.leaderboards:updateHistories(2 * 3600 * 24, ctx.leaderboard)
	ctx.leaderboards:updateHistories(2 * 3600 * 24, ctx.leaderboard)
	ctx.leaderboards:updateHistories(2 * 3600 * 24, ctx.leaderboard)

	local lb_user_his = ctx.db.models.leaderboard_user_histories:find({user_id = 1})
	---@cast lb_user_his sea.LeaderboardUserHistory

	t:eq(lb_user_his:getRank(1), 3)
	t:eq(lb_user_his:getRank(2), 2)
	t:eq(lb_user_his:getRank(3), 1)
	t:eq(lb_user_his:getRank(4), 1)

	ctx.db.models.leaderboard_users:update({rank = 4})

	ctx.leaderboards:updateHistories(10 * 3600 * 24, ctx.leaderboard)

	local lb_user_his = ctx.db.models.leaderboard_user_histories:find({user_id = 1})
	---@cast lb_user_his sea.LeaderboardUserHistory

	t:eq(lb_user_his:getRank(1), 4)
	t:eq(lb_user_his:getRank(8), 4)
	t:eq(lb_user_his:getRank(9), 3)
	t:eq(lb_user_his:getRank(10), 2)

	ctx.db.models.leaderboard_users:update({rank = 5})

	ctx.leaderboards:updateHistories(95 * 3600 * 24, ctx.leaderboard)

	local lb_user_his = ctx.db.models.leaderboard_user_histories:find({user_id = 1})
	---@cast lb_user_his sea.LeaderboardUserHistory

	t:eq(lb_user_his:getRank(1), 5)
	t:eq(lb_user_his:getRank(85), 5)
	t:eq(lb_user_his:getRank(86), 4)
	t:eq(lb_user_his:getRank(87), 4)
end

return test
