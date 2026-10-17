local class = require("class")
local sql_util = require("rdb.sql_util")

---@class sea.ChartplayEffectsRepo
---@operator call: sea.ChartplayEffectsRepo
local ChartplayEffectsRepo = class()

---@param models rdb.Models
function ChartplayEffectsRepo:new(models)
	self.models = models
end

---@param effect sea.ChartplayEffect
---@return sea.ChartplayEffect
function ChartplayEffectsRepo:createEffect(effect)
	return self.models.chartplay_effects:create(effect)
end

---@param id integer
---@return sea.ChartplayEffect?
function ChartplayEffectsRepo:getEffect(id)
	return self.models.chartplay_effects:find({id = assert(id)})
end

---@param chartplay_id integer
---@return sea.ChartplayEffect[]
function ChartplayEffectsRepo:getEffectsByChartplayId(chartplay_id)
	local effects = self.models.chartplay_effects:select({chartplay_id = assert(chartplay_id)}, {order = {"effect"}})
	---@cast effects sea.ChartplayEffect[]
	return effects
end

---@param state sea.ComputeJobState?
---@param limit integer?
---@return sea.ChartplayEffect[]
function ChartplayEffectsRepo:getEffects(state, limit)
	limit = math.min(math.max(limit or 100, 1), 1000)
	local effects = self.models.chartplay_effects:select(state and {state = state} or nil, {
		order = {"updated_at DESC", "id DESC"},
		limit = limit,
	})
	---@cast effects sea.ChartplayEffect[]
	return effects
end

---@param now integer
---@param lease_owner string
---@param lease_duration integer
---@param id integer?
---@return sea.ChartplayEffect?
function ChartplayEffectsRepo:claimEffect(now, lease_owner, lease_duration, id)
	local id_condition = id and "AND id = ?" or ""
	local values = {now, lease_owner, now + lease_duration, now, now}
	if id then
		table.insert(values, id)
	end
	local rows = self.models.chartplay_effects.orm:query(([=[
		UPDATE chartplay_effects
		SET state = 1,
			attempt_count = attempt_count + 1,
			updated_at = ?,
			lease_owner = ?,
			lease_expires_at = ?,
			last_error_kind = NULL,
			last_error_code = NULL,
			last_error_message = NULL
		WHERE id = (
			SELECT id FROM chartplay_effects effects
			WHERE attempt_count < max_attempts
			AND (state = 0 AND next_attempt_at <= ?
				OR state = 1 AND lease_expires_at <= ?)
			AND (effect != 5 OR NOT EXISTS (
				SELECT 1 FROM chartplay_effects dependency
				WHERE dependency.chartplay_id = effects.chartplay_id
				AND dependency.effect != 5 AND dependency.state != 2
			))
			%s
			ORDER BY created_at, id
			LIMIT 1
		)
	]=]):format(id_condition), values)
	if not rows[1] then
		return nil
	end
	return self.models.chartplay_effects:row_from_db(rows[1])
end

---@param effect sea.ChartplayEffect
---@param lease_owner string
---@param time integer
---@return sea.ChartplayEffect?
function ChartplayEffectsRepo:succeedEffect(effect, lease_owner, time)
	return self.models.chartplay_effects:update({
		state = "succeeded",
		updated_at = time,
		lease_owner = sql_util.NULL,
		lease_expires_at = sql_util.NULL,
	}, {
		id = assert(effect.id),
		state = "running",
		lease_owner = assert(lease_owner),
	})[1]
end

---@param effect sea.ChartplayEffect
---@param lease_owner string
---@param time integer
---@param failure sea.ComputeFailure
---@param retry_delay integer
---@return sea.ChartplayEffect?
function ChartplayEffectsRepo:retryEffect(effect, lease_owner, time, failure, retry_delay)
	local state = effect.attempt_count >= effect.max_attempts and "dead" or "queued"
	return self.models.chartplay_effects:update({
		state = state,
		updated_at = time,
		next_attempt_at = time + retry_delay,
		lease_owner = sql_util.NULL,
		lease_expires_at = sql_util.NULL,
		last_error_kind = failure.kind,
		last_error_code = failure.code,
		last_error_message = failure.message:sub(1, 4096),
	}, {
		id = assert(effect.id),
		state = "running",
		lease_owner = assert(lease_owner),
	})[1]
end

---@param id integer
---@param time integer
---@return sea.ChartplayEffect?
function ChartplayEffectsRepo:requeueEffect(id, time)
	return self.models.chartplay_effects:update({
		state = "queued",
		attempt_count = 0,
		updated_at = time,
		next_attempt_at = time,
		lease_owner = sql_util.NULL,
		lease_expires_at = sql_util.NULL,
		last_error_kind = sql_util.NULL,
		last_error_code = sql_util.NULL,
		last_error_message = sql_util.NULL,
	}, {
		id = assert(id),
		state = "dead",
	})[1]
end

return ChartplayEffectsRepo
