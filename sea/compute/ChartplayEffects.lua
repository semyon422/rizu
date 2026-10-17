local class = require("class")
local ComputeFailure = require("sea.compute.ComputeFailure")
local ChartplayEffect = require("sea.compute.ChartplayEffect")
local ChartplayEffectType = require("sea.compute.ChartplayEffectType")

---@class sea.ChartplayEffects
---@operator call: sea.ChartplayEffects
local ChartplayEffects = class()

ChartplayEffects.lease_duration = 60
ChartplayEffects.retry_delay = 5
ChartplayEffects.max_attempts = 5

---@param repo sea.ChartplayEffectsRepo
---@param charts_repo sea.ChartsRepo
---@param users_repo sea.UsersRepo
---@param leaderboards sea.Leaderboards
---@param user_activity_graph sea.UserActivityGraph
---@param dans sea.Dans
---@param external_ranked sea.ExternalRanked
---@param transaction fun(f: function, ...: any): ...any
---@param notify fun(chartplay: sea.Chartplay)
function ChartplayEffects:new(
	repo,
	charts_repo,
	users_repo,
	leaderboards,
	user_activity_graph,
	dans,
	external_ranked,
	transaction,
	notify
)
	self.repo = assert(repo)
	self.charts_repo = assert(charts_repo)
	self.users_repo = assert(users_repo)
	self.leaderboards = assert(leaderboards)
	self.user_activity_graph = assert(user_activity_graph)
	self.dans = assert(dans)
	self.external_ranked = assert(external_ranked)
	self.transaction = assert(transaction)
	self.notify = assert(notify)
	self.worker_id = ("effects:%d:%s"):format(os.time(), tostring({}):match("0x(.+)") or "worker")
	self.claim_index = 0
end

---@param chartplay_id integer
---@param time integer
---@param chart_upload_size integer
---@param replay_upload_size integer
function ChartplayEffects:createForChartplay(chartplay_id, time, chart_upload_size, replay_upload_size)
	for _, effect_type in ipairs(ChartplayEffectType:list()) do
		local effect = ChartplayEffect()
		effect.chartplay_id = chartplay_id
		effect.effect = effect_type
		effect.state = "queued"
		effect.attempt_count = 0
		effect.max_attempts = self.max_attempts
		effect.created_at = time
		effect.updated_at = time
		effect.next_attempt_at = time
		effect.chart_upload_size = chart_upload_size
		effect.replay_upload_size = replay_upload_size
		self.repo:createEffect(effect)
	end
end

---@param chartplay_id integer
---@return boolean
function ChartplayEffects:isComplete(chartplay_id)
	local effects = self.repo:getEffectsByChartplayId(chartplay_id)
	if #effects ~= #ChartplayEffectType:list() then
		return false
	end
	for _, effect in ipairs(effects) do
		if effect.state ~= "succeeded" then
			return false
		end
	end
	return true
end

---@param effect sea.ChartplayEffect
---@param chartplay sea.Chartplay
function ChartplayEffects:apply(effect, chartplay)
	local time = chartplay.submitted_at
	if effect.effect == "external_ranked" then
		local chartmeta = assert(self.charts_repo:getChartmetaByHashIndex(chartplay.hash, chartplay.index))
		self.external_ranked:submit(chartmeta, time)
	elseif effect.effect == "leaderboards" then
		if not chartplay.custom then
			self.leaderboards:addChartplay(chartplay)
		end
	elseif effect.effect == "activity" then
		self.transaction(function()
			self.user_activity_graph:recomputeUserActivity(chartplay.user_id)
		end)
	elseif effect.effect == "user_aggregates" then
		self.transaction(function()
			self.users_repo:updateUserSubmissionAggregates(chartplay.user_id)
		end)
	elseif effect.effect == "dan" then
		local user = assert(self.users_repo:getUser(chartplay.user_id))
		self.dans:submit(user, chartplay, chartplay, time)
	elseif effect.effect == "notification" then
		local ok, err = pcall(self.notify, chartplay)
		if not ok then
			print("chartplay completion notification failed: " .. tostring(err))
		end
	else
		error("unknown chartplay effect: " .. tostring(effect.effect))
	end
end

---@param id integer?
---@param time integer?
---@return sea.ChartplayEffect?
---@return sea.ComputeFailure?
function ChartplayEffects:process(id, time)
	time = time or os.time()
	self.claim_index = self.claim_index + 1
	local lease_owner = ("%s:%d"):format(self.worker_id, self.claim_index)
	local effect = self.repo:claimEffect(time, lease_owner, self.lease_duration, id)
	if not effect then
		return nil, ComputeFailure.transient("effect_not_claimable", "no chartplay effect is eligible for claim")
	end
	local chartplay = self.charts_repo:getChartplay(effect.chartplay_id)
	if not chartplay or chartplay.compute_state ~= "valid" then
		local failure = ComputeFailure.transient("chartplay_unavailable", "valid chartplay not found")
		assert(self.repo:retryEffect(effect, lease_owner, os.time(), failure, self.retry_delay))
		return nil, failure
	end

	local ok, err = xpcall(function()
		self:apply(effect, chartplay)
	end, debug.traceback)
	if not ok then
		local failure = ComputeFailure.transient("effect_failed", tostring(err))
		assert(self.repo:retryEffect(effect, lease_owner, os.time(), failure, self.retry_delay))
		return nil, failure
	end
	assert(self.repo:succeedEffect(effect, lease_owner, os.time()), "chartplay effect lease lost")
	return effect
end

---@param state sea.ComputeJobState?
---@param limit integer?
---@return sea.ChartplayEffect[]
function ChartplayEffects:getEffects(state, limit)
	return self.repo:getEffects(state, limit)
end

---@param id integer
---@param time integer?
---@return sea.ChartplayEffect?
---@return string?
function ChartplayEffects:requeue(id, time)
	local effect = self.repo:getEffect(id)
	if not effect then
		return nil, "chartplay effect not found"
	elseif effect.state ~= "dead" then
		return nil, "chartplay effect is not dead"
	end
	return assert(self.repo:requeueEffect(id, time or os.time()))
end

return ChartplayEffects
