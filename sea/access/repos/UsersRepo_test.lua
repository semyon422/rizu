local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local UsersRepo = require("sea.access.repos.UsersRepo")
local UserInsecure = require("sea.access.UserInsecure")
local TestChartFactory = require("sea.chart.TestChartFactory")

local test = {}

---@param repo sea.UsersRepo
---@param name string
---@return sea.User
local function create_user(repo, name)
	local user = UserInsecure()
	user.name = name
	user.email = name .. "@example.invalid"
	user.password = "test"
	user.created_at = 1
	user.latest_activity = 1
	user.chartplays_count = 99
	user.chartmetas_count = 99
	user.chartdiffs_count = 99
	user.play_time = 999
	user.chartplays_upload_size = 424242
	return repo:createUser(user)
end

local function create_ctx()
	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:open()
	local repo = UsersRepo(db.models)
	return {db = db, repo = repo, user = create_user(repo, "player"), factory = TestChartFactory()}
end

---@param t testing.T
function test.submission_aggregates_count_only_valid_plays(t)
	local ctx = create_ctx()
	local other = create_user(ctx.repo, "other")
	local hash_a, hash_b = string.rep("a", 32), string.rep("b", 32)
	for _, diff in ipairs({
		{hash = hash_a, rate = 1, duration = 120},
		{hash = hash_a, rate = 2, duration = 120},
		{hash = hash_b, rate = 1, duration = 30},
	}) do
		ctx.db.models.chartdiffs:create(ctx.factory:createChartdiff(diff))
	end
	for i, values in ipairs({
		{hash = hash_a, rate = 1, compute_state = "valid", submitted_at = 10},
		{hash = hash_a, rate = 1, compute_state = "valid", submitted_at = 15},
		{hash = hash_a, rate = 2, compute_state = "valid", submitted_at = 20},
		{hash = hash_b, rate = 1, compute_state = "valid", submitted_at = 30},
		{hash = hash_a, rate = 1, compute_state = "invalid", submitted_at = 9999},
		{hash = hash_b, rate = 1, compute_state = "new", submitted_at = 8888},
		{hash = hash_b, rate = 1, compute_state = "valid", submitted_at = 7777, user_id = other.id},
	}) do
		values.user_id = values.user_id or ctx.user.id
		values.replay_hash = string.format("%032d", i)
		ctx.db.models.chartplays:create(ctx.factory:createChartplay(values))
	end
	for i, owner in ipairs({ctx.user.id, ctx.user.id, other.id}) do
		ctx.db.models.chartfiles:create({
			hash = string.format("%032d", i), name = "chart.osu", size = i * 100,
			creator_id = owner, compute_state = "valid", computed_at = 0, submitted_at = 0,
		})
	end

	for _ = 1, 2 do
		ctx.repo:updateUserSubmissionAggregates(ctx.user.id)
		local user = assert(ctx.repo:getUser(ctx.user.id))
		t:eq(user.chartplays_count, 4)
		t:eq(user.chartmetas_count, 2)
		t:eq(user.chartdiffs_count, 3)
		t:eq(user.latest_activity, 30)
		t:eq(user.play_time, 330)
		t:eq(user.chartfiles_upload_size, 300)
		t:eq(user.chartplays_upload_size, 424242)
	end
	local unaffected = assert(ctx.repo:getUser(other.id))
	t:eq(unaffected.chartplays_count, 99)
	t:eq(unaffected.play_time, 999)
	t:eq(unaffected.chartplays_upload_size, 424242)
	ctx.db:close()
end

---@param t testing.T
function test.play_time_accounts_for_playback_rate(t)
	local ctx = create_ctx()
	local hash = string.rep("a", 32)
	for i, rate in ipairs({1, 2}) do
		ctx.db.models.chartdiffs:create(ctx.factory:createChartdiff({hash = hash, rate = rate, duration = 120}))
		ctx.db.models.chartplays:create(ctx.factory:createChartplay({
			user_id = ctx.user.id, hash = hash, rate = rate, compute_state = "valid",
			replay_hash = string.format("%032d", i),
		}))
	end

	ctx.repo:updateUserSubmissionAggregates(ctx.user.id)
	t:eq(assert(ctx.repo:getUser(ctx.user.id)).play_time, 180)
	ctx.db:close()
end

---@param t testing.T
function test.historical_upload_total_survives_recomputation_without_jobs(t)
	local ctx = create_ctx()
	ctx.db.models.chartplays:create(ctx.factory:createChartplay({
		user_id = ctx.user.id, compute_state = "valid", hash = string.rep("a", 32),
	}))
	for _ = 1, 2 do
		ctx.repo:updateUserSubmissionAggregates(ctx.user.id)
		t:eq(assert(ctx.repo:getUser(ctx.user.id)).chartplays_upload_size, 424242)
	end
	ctx.db:close()
end

---@param t testing.T
function test.no_valid_plays_resets_counts_but_preserves_upload_history(t)
	local ctx = create_ctx()
	for i, state in ipairs({"new", "invalid"}) do
		ctx.db.models.chartplays:create(ctx.factory:createChartplay({
			user_id = ctx.user.id, compute_state = state, hash = string.rep("a", 32),
			replay_hash = string.format("%032d", i), submitted_at = 100,
		}))
	end
	ctx.repo:updateUserSubmissionAggregates(ctx.user.id)
	local user = assert(ctx.repo:getUser(ctx.user.id))
	t:eq(user.chartplays_count, 0)
	t:eq(user.chartmetas_count, 0)
	t:eq(user.chartdiffs_count, 0)
	t:eq(user.play_time, 0)
	t:eq(user.latest_activity, 1)
	t:eq(user.chartplays_upload_size, 424242)
	ctx.db:close()
end

---@param t testing.T
function test.upload_increment_preserves_history_and_rejects_invalid_sizes(t)
	local ctx = create_ctx()
	ctx.repo:addChartplayUploadSize(ctx.user.id, 7)
	ctx.repo:addChartplayUploadSize(ctx.user.id, 0)
	t:has_error(ctx.repo.addChartplayUploadSize, ctx.repo, ctx.user.id, -1)
	t:has_error(ctx.repo.addChartplayUploadSize, ctx.repo, ctx.user.id, 0.5)
	local user = assert(ctx.repo:getUser(ctx.user.id))
	t:eq(user.chartplays_upload_size, 424249)
	t:eq(user.chartplays_count, 99)
	ctx.db:close()
end

return test
