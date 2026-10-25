local class = require("class")
local string_buffer = require("string.buffer")
local zlib = require("zlib")

---@class rizu.library.ChartplayAccuracy: rizu.engine.ScoreEngine.StoredAccuracies.Row
---@field chartplay_id integer

---What the score engine received in a play: enough to score it in any system without the replay.
---@class rizu.library.ChartplayHits
---@field notes_count integer
---@field inputmode string
---@field events rizu.LogicNoteChange[]

---@class rizu.library.repos.ChartplayAccuraciesRepo
---@operator call: rizu.library.repos.ChartplayAccuraciesRepo
local ChartplayAccuraciesRepo = class()

-- Raise it when the engine judges the same replay differently, so the hits are made again from the replays.
ChartplayAccuraciesRepo.hits_version = 1

-- The fields of rizu.LogicNoteChange, written as one byte each.
local buffer = string_buffer.new({dict = {
	"index", "column", "type", "time", "delta_time", "press_delta_time", "old_state", "new_state",
}})

---@param models rdb.Models
function ChartplayAccuraciesRepo:new(models)
	self.models = models
end

---@param chartplay_id integer
---@return rizu.library.ChartplayAccuracy[]
function ChartplayAccuraciesRepo:getAccuracies(chartplay_id)
	return self.models.chartplay_accuracies:select({chartplay_id = assert(chartplay_id)})
end

---Which accuracies every chartplay has, as "timings:subtimings" keys.
---@return {[integer]: {[string]: true}}
function ChartplayAccuraciesRepo:getAccuracyKeys()
	---@type {[integer]: {[string]: true}}
	local keys = {}
	for _, row in ipairs(self.models.chartplay_accuracies:select()) do
		---@cast row rizu.library.ChartplayAccuracy
		local chartplay_keys = keys[row.chartplay_id] or {}
		keys[row.chartplay_id] = chartplay_keys
		chartplay_keys[row.timings .. ":" .. row.subtimings] = true
	end
	return keys
end

---Replaces every stored accuracy of the chartplay with these.
---@param chartplay_id integer
---@param rows rizu.engine.ScoreEngine.StoredAccuracies.Row[]
function ChartplayAccuraciesRepo:setAccuracies(chartplay_id, rows)
	self.models.chartplay_accuracies:delete({chartplay_id = assert(chartplay_id)})
	if not rows[1] then
		return
	end
	---@type rizu.library.ChartplayAccuracy[]
	local values = {}
	for i, row in ipairs(rows) do
		values[i] = {
			chartplay_id = chartplay_id,
			timings = row.timings,
			subtimings = row.subtimings,
			accuracy = row.accuracy,
		}
	end
	self.models.chartplay_accuracies:insert(values)
end

---@param chartplay_id integer
---@param chartdiff {notes_count: integer, inputmode: string} The one the play was scored with.
---@param events rizu.LogicNoteChange[] rizu.ScoreEngine.events
function ChartplayAccuraciesRepo:setHits(chartplay_id, chartdiff, events)
	local values = {
		chartplay_id = assert(chartplay_id),
		version = ChartplayAccuraciesRepo.hits_version,
		notes_count = chartdiff.notes_count,
		inputmode = chartdiff.inputmode,
		events = zlib.compress(buffer:reset():encode(events):get()),
	}
	self.models.chartplay_hits:delete({chartplay_id = chartplay_id})
	self.models.chartplay_hits:create(values)
end

---@param chartplay_id integer
---@return rizu.library.ChartplayHits? hits nil when not stored, or stored by an older version.
function ChartplayAccuraciesRepo:getHits(chartplay_id)
	local row = self.models.chartplay_hits:find({chartplay_id = assert(chartplay_id)})
	if not row or row.version ~= ChartplayAccuraciesRepo.hits_version then
		return
	end
	return {
		notes_count = row.notes_count,
		inputmode = row.inputmode,
		events = buffer:set(zlib.uncompress(row.events)):decode(),
	}
end

return ChartplayAccuraciesRepo
