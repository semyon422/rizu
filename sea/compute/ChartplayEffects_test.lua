local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local ChartplayEffectsRepo = require("sea.compute.repos.ChartplayEffectsRepo")
local ChartplayEffect = require("sea.compute.ChartplayEffect")
local ChartplayEffectType = require("sea.compute.ChartplayEffectType")
local ComputeFailure = require("sea.compute.ComputeFailure")
local ChartplayEffects = require("sea.compute.ChartplayEffects")
local UsersRepo = require("sea.access.repos.UsersRepo")
local UserInsecure = require("sea.access.UserInsecure")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local TestChartFactory = require("sea.chart.TestChartFactory")

local test = {}

local function create_ctx()
	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:open()
	local chartplay = db.models.chartplays:create({
		user_id = 1, compute_state = "valid", computed_at = 0, submitted_at = 0,
		replay_hash = "00000000000000000000000000000000", pause_count = 0, created_at = 0,
		hash = "11111111111111111111111111111111", index = 1,
		modifiers = {}, rate = 1, mode = "mania", nearest = false, tap_only = false,
		custom = false, const = false, rate_type = "linear", judges = {}, accuracy = 0,
		max_combo = 0, miss_count = 0, not_perfect_count = 0, pass = false,
		rating = 0, rating_pp = 0, rating_msd = 0,
	})
	local repo = ChartplayEffectsRepo(db.models)
	for _, effect_type in ipairs(ChartplayEffectType:list()) do
		local effect = ChartplayEffect()
		effect.chartplay_id = chartplay.id
		effect.effect = effect_type
		effect.state = "queued"
		effect.attempt_count = 0
		effect.max_attempts = 2
		effect.created_at = 0
		effect.updated_at = 0
		effect.next_attempt_at = 0
		effect.chart_upload_size = 0
		effect.replay_upload_size = 0
		repo:createEffect(effect)
	end
	return {db = db, repo = repo, chartplay = chartplay}
end

---@param t testing.T
function test.notification_waits_for_dependencies(t)
	local ctx = create_ctx()
	for _ = 1, #ChartplayEffectType:list() - 1 do
		local effect = assert(ctx.repo:claimEffect(0, "worker", 10))
		t:ne(effect.effect, "notification")
		assert(ctx.repo:succeedEffect(effect, "worker", 0))
	end
	local effect = assert(ctx.repo:claimEffect(0, "worker", 10))
	t:eq(effect.effect, "notification")
	ctx.db:close()
end

---@param t testing.T
function test.retry_dead_and_requeue(t)
	local ctx = create_ctx()
	local failure = ComputeFailure.transient("effect_failed", "boom")
	local effect = assert(ctx.repo:claimEffect(0, "worker", 10))
	effect = assert(ctx.repo:retryEffect(effect, "worker", 0, failure, 5))
	t:eq(effect.state, "queued")
	effect = assert(ctx.repo:claimEffect(5, "worker", 10, effect.id))
	effect = assert(ctx.repo:retryEffect(effect, "worker", 5, failure, 5))
	t:eq(effect.state, "dead")
	effect = assert(ctx.repo:requeueEffect(effect.id, 10))
	t:eq(effect.state, "queued")
	t:eq(effect.attempt_count, 0)
	ctx.db:close()
end

---@param t testing.T
function test.unique_effect_key(t)
	local ctx = create_ctx()
	local effect = ctx.repo:getEffectsByChartplayId(ctx.chartplay.id)[1]
	effect.id = nil
	t:has_error(ctx.repo.createEffect, ctx.repo, effect)
	ctx.db:close()
end

local function create_aggregate_ctx()
	local ctx = create_ctx()
	local users_repo = UsersRepo(ctx.db.models)
	local user = UserInsecure()
	user.name = "player"
	user.email = "player@example.invalid"
	user.password = "test"
	user.created_at = 0
	user.latest_activity = 0
	user.chartplays_count = 99
	user.chartplays_upload_size = 1000
	local saved_user = users_repo:createUser(user)
	---@type sea.ChartplayEffect?
	local aggregate_effect
	for _, effect in ipairs(ctx.repo:getEffectsByChartplayId(ctx.chartplay.id)) do
		if effect.effect == "user_aggregates" then aggregate_effect = effect end
	end
	aggregate_effect = assert(aggregate_effect)
	ctx.db.models.chartplay_effects:update({replay_upload_size = 128}, {id = aggregate_effect.id})

	---@param callback fun()
	local function transaction(callback)
		ctx.db.orm:begin()
		local ok, err = xpcall(callback, debug.traceback)
		if not ok then
			ctx.db.db:exec("ROLLBACK")
			error(err)
		end
		ctx.db.orm:commit()
	end
	---@type {chartplay_id: integer, count: integer, upload_size: integer}[]
	local notifications = {}
	---@param chartplay sea.Chartplay
	local function notify(chartplay)
		local current_user = assert(users_repo:getUser(chartplay.user_id))
		table.insert(notifications, {chartplay_id = chartplay.id,
			count = current_user.chartplays_count, upload_size = current_user.chartplays_upload_size})
	end
	---@return sea.ChartplayEffects
	local function create_worker()
		return ChartplayEffects(ctx.repo, ChartsRepo(ctx.db.models, {}), users_repo,
			{}, {}, {}, {}, transaction, notify)
	end
	return {db = ctx.db, repo = ctx.repo, users_repo = users_repo, user = saved_user,
		effect = aggregate_effect, worker = create_worker(), create_worker = create_worker, notifications = notifications}
end

---@param t testing.T
function test.user_aggregate_upload_is_preserved_and_added_once(t)
	local ctx = create_aggregate_ctx()
	local effect = assert(ctx.worker:process(ctx.effect.id, 0))
	t:eq(effect.effect, "user_aggregates")
	t:eq(assert(ctx.repo:getEffect(ctx.effect.id)).state, "succeeded")
	local user = assert(ctx.users_repo:getUser(ctx.user.id))
	t:eq(user.chartplays_count, 1)
	t:eq(user.chartplays_upload_size, 1128)
	t:eq(ctx.worker:process(ctx.effect.id, 1000), nil)
	t:eq(assert(ctx.users_repo:getUser(ctx.user.id)).chartplays_upload_size, 1128)
	ctx.db:close()
end

---@param t testing.T
function test.user_aggregate_failure_rolls_back_counts_upload_and_completion(t)
	local ctx = create_aggregate_ctx()
	local fail = true
	function ctx.repo:succeedEffect(effect, lease_owner, time)
		local result = ChartplayEffectsRepo.succeedEffect(self, effect, lease_owner, time)
		if fail then error("injected failure after effect completion write") end
		return result
	end

	local effect, failure = ctx.worker:process(ctx.effect.id, 0)
	t:eq(effect, nil)
	t:eq(assert(failure).code, "effect_failed")
	local user = assert(ctx.users_repo:getUser(ctx.user.id))
	t:eq(user.chartplays_count, 99)
	t:eq(user.chartplays_upload_size, 1000)
	local queued = assert(ctx.repo:getEffect(ctx.effect.id))
	t:eq(queued.state, "queued")

	fail = false
	t:assert(ctx.worker:process(ctx.effect.id, queued.next_attempt_at))
	t:eq(assert(ctx.repo:getEffect(ctx.effect.id)).state, "succeeded")
	user = assert(ctx.users_repo:getUser(ctx.user.id))
	t:eq(user.chartplays_count, 1)
	t:eq(user.chartplays_upload_size, 1128)
	ctx.db:close()
end

---@param t testing.T
function test.notification_observes_committed_user_aggregates(t)
	local ctx = create_aggregate_ctx()
	---@type integer?
	local notification_id
	for _, effect in ipairs(ctx.repo:getEffectsByChartplayId(ctx.effect.chartplay_id)) do
		if effect.effect == "notification" then
			notification_id = effect.id
		elseif effect.effect ~= "user_aggregates" then
			local claimed = assert(ctx.repo:claimEffect(0, "worker", 10, effect.id))
			assert(ctx.repo:succeedEffect(claimed, "worker", 0))
		end
	end
	notification_id = assert(notification_id)
	t:eq(ctx.worker:process(notification_id, 0), nil)
	t:eq(#ctx.notifications, 0)
	t:assert(ctx.worker:process(ctx.effect.id, 0))
	t:assert(ctx.worker:process(notification_id, 0))
	t:assert(ctx.worker:isComplete(ctx.effect.chartplay_id))
	t:eq(#ctx.notifications, 1)
	t:eq(ctx.notifications[1].count, 1)
	t:eq(ctx.notifications[1].upload_size, 1128)
	t:eq(assert(ctx.users_repo:getUser(ctx.user.id)).chartplays_count, 1)
	t:eq(assert(ctx.users_repo:getUser(ctx.user.id)).chartplays_upload_size, 1128)
	ctx.db:close()
end

---@param t testing.T
function test.completed_upload_is_not_added_again_after_worker_restart(t)
	local ctx = create_aggregate_ctx()
	local transaction = ctx.worker.transaction
	ctx.worker.transaction = function(callback)
		transaction(callback)
		error("injected lost response after commit")
	end
	t:has_error(ctx.worker.process, ctx.worker, ctx.effect.id, 0)
	t:eq(assert(ctx.repo:getEffect(ctx.effect.id)).state, "succeeded")
	local restarted = ctx.create_worker()
	t:eq(restarted:process(ctx.effect.id, 1000), nil)
	t:eq(assert(ctx.users_repo:getUser(ctx.user.id)).chartplays_count, 1)
	t:eq(assert(ctx.users_repo:getUser(ctx.user.id)).chartplays_upload_size, 1128)
	ctx.db:close()
end

---@param t testing.T
function test.distinct_upload_effects_accumulate_in_any_order(t)
	local ctx = create_aggregate_ctx()
	local chartplay = TestChartFactory():createChartplay({
		user_id = ctx.user.id, compute_state = "valid", hash = string.rep("2", 32),
		replay_hash = string.rep("2", 32),
	})
	chartplay = ctx.worker.charts_repo:createChartplay(chartplay)
	ctx.worker:createForChartplay(chartplay.id, 1, 0, 256)
	for _, effect in ipairs(ctx.repo:getEffectsByChartplayId(chartplay.id)) do
		if effect.effect == "user_aggregates" then
			t:assert(ctx.worker:process(effect.id, 1))
		end
	end
	t:assert(ctx.worker:process(ctx.effect.id, 1))
	local user = assert(ctx.users_repo:getUser(ctx.user.id))
	t:eq(user.chartplays_count, 2)
	t:eq(user.chartplays_upload_size, 1384)
	ctx.db:close()
end

---@param t testing.T
function test.lost_lease_rolls_back_upload_before_successor_recovers(t)
	local ctx = create_aggregate_ctx()
	local stolen = false
	function ctx.worker.charts_repo:getChartplay(id)
		local chartplay = ChartsRepo.getChartplay(self, id)
		if not stolen then
			ctx.db.models.chartplay_effects:update({lease_owner = "successor"}, {id = ctx.effect.id})
			stolen = true
		end
		return chartplay
	end
	t:has_error(ctx.worker.process, ctx.worker, ctx.effect.id, 0)
	local user = assert(ctx.users_repo:getUser(ctx.user.id))
	t:eq(user.chartplays_count, 99)
	t:eq(user.chartplays_upload_size, 1000)
	t:eq(assert(ctx.repo:getEffect(ctx.effect.id)).lease_owner, "successor")
	t:assert(ctx.create_worker():process(ctx.effect.id, 60))
	t:eq(assert(ctx.users_repo:getUser(ctx.user.id)).chartplays_upload_size, 1128)
	ctx.db:close()
end

---@param t testing.T
function test.nonvalid_plays_do_not_apply_user_aggregates(t)
	for _, state in ipairs({"new", "invalid"}) do
		local ctx = create_aggregate_ctx()
		ctx.db.models.chartplays:update({compute_state = state}, {id = ctx.effect.chartplay_id})
		local effect, failure = ctx.worker:process(ctx.effect.id, 0)
		t:eq(effect, nil)
		t:eq(assert(failure).code, "chartplay_unavailable")
		local user = assert(ctx.users_repo:getUser(ctx.user.id))
		t:eq(user.chartplays_count, 99)
		t:eq(user.chartplays_upload_size, 1000)
		ctx.db:close()
	end
end

return test
