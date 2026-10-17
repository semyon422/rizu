local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local ChartplayEffectsRepo = require("sea.compute.repos.ChartplayEffectsRepo")
local ChartplayEffect = require("sea.compute.ChartplayEffect")
local ChartplayEffectType = require("sea.compute.ChartplayEffectType")
local ComputeFailure = require("sea.compute.ComputeFailure")

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

return test
