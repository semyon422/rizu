local class = require("class")
local string_buffer = require("string.buffer")
local zlib = require("zlib")

---What the score engine received in a play: enough to score it in any system without the replay.
---@class rizu.library.ChartplayHits
---@field notes_count integer
---@field inputmode string
---@field events rizu.LogicNoteChange[]

---@class rizu.library.repos.ChartplayHitsRepo
---@operator call: rizu.library.repos.ChartplayHitsRepo
local ChartplayHitsRepo = class()

-- Raise it when the engine judges the same replay differently, so the hits are made again from the replays.
ChartplayHitsRepo.hits_version = 1

-- The fields of rizu.LogicNoteChange, written as one byte each.
local buffer = string_buffer.new({dict = {
	"index", "column", "type", "time", "delta_time", "press_delta_time", "old_state", "new_state",
}})

---@param models rdb.Models
function ChartplayHitsRepo:new(models)
	self.models = models
end

---@param chartplay_id integer
---@param chartdiff {notes_count: integer, inputmode: string} The one the play was scored with.
---@param events rizu.LogicNoteChange[] rizu.ScoreEngine.events
function ChartplayHitsRepo:setHits(chartplay_id, chartdiff, events)
	local values = {
		chartplay_id = assert(chartplay_id),
		version = ChartplayHitsRepo.hits_version,
		notes_count = chartdiff.notes_count,
		inputmode = chartdiff.inputmode,
		events = zlib.compress(buffer:reset():encode(events):get()),
	}
	self.models.chartplay_hits:delete({chartplay_id = chartplay_id})
	self.models.chartplay_hits:create(values)
end

---@param chartplay_id integer
---@return rizu.library.ChartplayHits? hits nil when not stored, or stored by an older version.
function ChartplayHitsRepo:getHits(chartplay_id)
	local row = self.models.chartplay_hits:find({chartplay_id = assert(chartplay_id)})
	if not row or row.version ~= ChartplayHitsRepo.hits_version then
		return
	end
	return {
		notes_count = row.notes_count,
		inputmode = row.inputmode,
		events = buffer:set(zlib.uncompress(row.events)):decode(),
	}
end

---Chartplays whose hits of this version are stored, without reading the hits.
---@return {[integer]: true}
function ChartplayHitsRepo:getStoredIds()
	---@type {[integer]: true}
	local ids = {}
	local rows = self.models.chartplay_hits:select({version = ChartplayHitsRepo.hits_version},
		{columns = {"chartplay_id"}})
	for _, row in ipairs(rows) do
		ids[row.chartplay_id] = true
	end
	return ids
end

return ChartplayHitsRepo
