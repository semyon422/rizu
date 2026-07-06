local IDiffcalc = require("chart.difficulty.IDiffcalc")

---@class chart.NotesDiffcalc: chart.IDiffcalc
---@operator call: chart.NotesDiffcalc
local NotesDiffcalc = IDiffcalc + {}

NotesDiffcalc.name = "notes"
NotesDiffcalc.chartdiff_field = "notes_count"

---@param ctx chart.DiffcalcContext
function NotesDiffcalc:compute(ctx)
	local chartdiff = ctx.chartdiff

	local min_time = math.huge
	local max_time = -math.huge

	-- TODO: fix for other note types
	local count = {
		tap = 0,
		hold = 0,
	}

	for _, linked_note in ipairs(ctx.chart.notes:getLinkedNotes()) do
		local _type = linked_note:getType()
		if count[_type] then
			local a, b = linked_note:getStartTime(), linked_note:getEndTime()
			min_time = math.min(min_time, a, b)
			max_time = math.max(max_time, a, b)
			count[_type] = count[_type] + 1
		end
	end

	if min_time == math.huge then
		min_time, max_time = 0, 0
	end

	chartdiff.note_types_count = count
	chartdiff.notes_count = count.tap + count.hold
	chartdiff.judges_count = count.tap + count.hold * 2

	chartdiff.start_time = min_time
	chartdiff.duration = max_time - min_time

	-- stubs for future fields
	chartdiff.density_data = {}
	chartdiff.sv_data = {}
	chartdiff.user_diff = chartdiff.user_diff or 0
	chartdiff.user_diff_data = chartdiff.user_diff_data or ""
end

return NotesDiffcalc
