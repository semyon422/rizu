local ComputeContext = require("sea.compute.ComputeContext")
local ReplayBase = require("sea.replays.ReplayBase")
local InputMode = require("chart.core.InputMode")
local chart_samples = require("sea.chart.samples.Samples")

local test = {}

---@param t testing.T
function test.modifier_reorder(t)
	local ctx = ComputeContext()
	local rb = ReplayBase()
	local im = InputMode("4key")

	rb.modifiers = {
		{id = 14, value = "key", version = 0}, -- alternate
		{id = 16, value = "all", version = 0}, -- mirror all
		{id = 11, value = 4, version = 0}, -- automap 4
		{id = 15, value = 2, version = 0}, -- shift 2
		{id = 15, value = -1, version = 0}, -- shift -1
	}
	rb.columns_order = {4, 3, 2, 1}

	ctx:applyModifierReorder(rb, im)

	t:tdeq(rb.modifiers, {
		{id = 14, value = "key", version = 0},
		{id = 16, value = "all", version = 0},
		{id = 11, value = 4, version = 0},
	})
	t:tdeq(rb.columns_order, {3, 2, 1, 4})
end

---@param t testing.T
function test.swap_modifier_keeps_notes_for_next_modifier(t)
	local sample = chart_samples[1]
	local ctx = ComputeContext()
	assert(ctx:fromFileData(sample.name, sample.data, 1))
	local count = #ctx.chart.notes:getLinkedNotes()

	local rb = ReplayBase()
	rb.modifiers = {
		{id = 16, value = "all", version = 0}, -- mirror all
		{id = 14, value = "key", version = 0}, -- alternate
	}
	ctx:computeBase(rb)

	t:assert(count > 0)
	t:eq(#ctx.chart.notes:getLinkedNotes(), count)
end

return test
