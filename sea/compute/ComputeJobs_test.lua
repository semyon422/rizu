local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")
local ComputeJobsRepo = require("sea.compute.repos.ComputeJobsRepo")
local ComputeJob = require("sea.compute.ComputeJob")
local ComputeFailure = require("sea.compute.ComputeFailure")
local Chartdiff = require("sea.chart.Chartdiff")

local test = {}

local function create_ctx()
	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:open()
	local chartplay = db.models.chartplays:create({
		user_id = 1, compute_state = "new", computed_at = 0, submitted_at = 0,
		replay_hash = "00000000000000000000000000000000", pause_count = 0, created_at = 0,
		hash = "11111111111111111111111111111111", index = 1,
		modifiers = {}, rate = 1, mode = "mania", nearest = false, tap_only = false,
		custom = false, const = false, rate_type = "linear", judges = {}, accuracy = 0,
		max_combo = 0, miss_count = 0, not_perfect_count = 0, pass = false,
		rating = 0, rating_pp = 0, rating_msd = 0,
	})
	local chartdiff = Chartdiff()
	local job = ComputeJob()
	job.chartplay_id = chartplay.id
	job.idempotency_key = chartplay.replay_hash
	job.state = "queued"
	job.attempt_count = 0
	job.max_attempts = 3
	job.created_at = 0
	job.updated_at = 0
	job.next_attempt_at = 0
	job.compute_version = "test"
	job.chartdiff = chartdiff
	local repo = ComputeJobsRepo(db.models)
	job = repo:createComputeJob(job)
	return {db = db, repo = repo, job = job, chartplay = chartplay}
end

---@param t testing.T
function test.claim_and_lease_recovery(t)
	local ctx = create_ctx()
	local job = assert(ctx.repo:claimComputeJob(0, "worker-a", 10, ctx.job.id))
	t:eq(job.state, "running")
	t:eq(job.attempt_count, 1)
	t:eq(ctx.repo:claimComputeJob(9, "worker-b", 10, ctx.job.id), nil)

	job = assert(ctx.repo:claimComputeJob(10, "worker-b", 10, ctx.job.id))
	t:eq(job.lease_owner, "worker-b")
	t:eq(job.attempt_count, 2)
	ctx.db:close()
end

---@param t testing.T
function test.retry_and_dead(t)
	local ctx = create_ctx()
	local failure = ComputeFailure.transient("worker_unavailable", "offline")
	local job = assert(ctx.repo:claimComputeJob(0, "worker", 10, ctx.job.id))
	job = assert(ctx.repo:retryComputeJob(job, "worker", 0, failure, 5))
	t:eq(job.state, "queued")
	t:eq(job.next_attempt_at, 5)

	job = assert(ctx.repo:claimComputeJob(5, "worker", 10, ctx.job.id))
	job = assert(ctx.repo:retryComputeJob(job, "worker", 5, failure, 5))
	t:eq(job.state, "queued")
	job = assert(ctx.repo:claimComputeJob(10, "worker", 10, ctx.job.id))
	job = assert(ctx.repo:retryComputeJob(job, "worker", 10, failure, 5))
	t:eq(job.state, "dead")
	t:eq(job.last_error_code, "worker_unavailable")
	ctx.db:close()
end

---@param t testing.T
function test.unique_replay_hash(t)
	local ctx = create_ctx()
	local values = {}
	for key, value in pairs(ctx.chartplay) do
		values[key] = value
	end
	values.id = nil
	values.user_id = 2
	t:has_error(ctx.db.models.chartplays.create, ctx.db.models.chartplays, values)
	ctx.db:close()
end

---@param t testing.T
function test.permanent_failure(t)
	local ctx = create_ctx()
	local job = assert(ctx.repo:claimComputeJob(0, "worker", 10, ctx.job.id))
	job = assert(ctx.repo:failComputeJob(job, "worker", 0, ComputeFailure.permanent("invalid_replay", "bad")))
	t:eq(job.state, "failed")
	t:eq(job.last_error_kind, "permanent")
	t:eq(ctx.repo:claimComputeJob(100, "worker", 10, ctx.job.id), nil)
	ctx.db:close()
end

return test
