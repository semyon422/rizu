local class = require("class")
local Osr = require("chart.format.osu.Osr")

---@class sea.OsrConverter
---@operator call: sea.OsrConverter
local OsrConverter = class()

---@param chartmeta sea.Chartmeta
---@param replay sea.Replay
---@return string
---@return string
function OsrConverter:saveOsr(chartmeta, replay)
	local osr = Osr()

	osr.beatmap_hash = assert(replay.hash)

	---@type [integer, integer, boolean][]
	local mania_events = {}
	for i, f in ipairs(replay.frames) do
		mania_events[i] = {
			math.floor(f.time * 1000),
			f.event.column,
			not not f.event.value
		}
	end
	osr:encodeManiaEvents(mania_events)
	osr:setTimestamp(replay.created_at)

	local data = osr:encode()

	local display_title = ("%s - %s [%s]"):format(
		chartmeta.artist, chartmeta.title, chartmeta.name
	)

	local name = ("%s - %s (%s) OsuMania.osr"):format(
		osr.player_name,
		display_title,
		os.date("%Y-%m-%d", osr:getTimestamp())
	)

	return name, data
end

return OsrConverter
