local class = require("class")
local table_util = require("table_util")
local PrimitiveArray = require("chart.refchart.PrimitiveArray")
local Fraction = require("chart.core.Fraction")
local InputMode = require("chart.core.InputMode")
local Chart = require("chart.model.Chart")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local Note = require("chart.model.notes.Note")
local LinkedNote = require("chart.model.notes.LinkedNote")
local Tempo = require("chart.model.to.Tempo")
local Measure = require("chart.model.to.Measure")
local Visual = require("chart.model.visual.Visual")
local Expand = require("chart.model.visual.Expand")
local Velocity = require("chart.model.visual.Velocity")

---@class refchart.SnapshotRestorer
---@operator call: refchart.SnapshotRestorer
local SnapshotRestorer = class()

---@alias refchart.RestoreCheckpoint fun(): boolean?

---@param snapshot refchart.ChartSnapshot
---@param checkpoint refchart.RestoreCheckpoint?
---@return chart.Chart? chart
function SnapshotRestorer:restore(snapshot, checkpoint)
	local work_count = 0
	local function continue_restore()
		work_count = work_count + 1
		if work_count % 256 == 0 and checkpoint then
			return checkpoint() ~= false
		end
		return true
	end

	local chart = Chart()
	chart.inputMode = InputMode(snapshot.inputmode)
	chart.data = table_util.deepcopy(snapshot.data)

	---@type chart.VisualPoint[]
	local visual_points = {}
	for _, snapshot_layer in ipairs(snapshot.layers) do
		local layer = AbsoluteLayer()
		chart.layers[snapshot_layer.name] = layer

		local point_times = PrimitiveArray.doubles(snapshot_layer.point_times)
		local tempo_indexes = PrimitiveArray.uint32(snapshot_layer.tempo_indexes)
		local tempos = PrimitiveArray.doubles(snapshot_layer.tempos)
		local measure_indexes = PrimitiveArray.uint32(snapshot_layer.measure_indexes)
		local measure_numerators = PrimitiveArray.doubles(snapshot_layer.measure_numerators)
		local measure_denominators = PrimitiveArray.doubles(snapshot_layer.measure_denominators)
		---@type chart.AbsolutePoint[]
		local points = {}
		local tempo_cursor = 0
		local measure_cursor = 0
		---@type chart.Tempo?
		local tempo
		---@type chart.Measure?
		local measure
		for point_offset = 0, snapshot_layer.point_count - 1 do
			local point_index = point_offset + 1
			local point = layer:getPoint(tonumber(point_times[point_offset]))
			points[point_index] = point
			if tempo_cursor < snapshot_layer.tempo_count and tonumber(tempo_indexes[tempo_cursor]) == point_index then
				tempo = Tempo(tonumber(tempos[tempo_cursor]))
				tempo.point = point
				point._tempo = tempo
				tempo_cursor = tempo_cursor + 1
			end
			if measure_cursor < snapshot_layer.measure_count and tonumber(measure_indexes[measure_cursor]) == point_index then
				measure = Measure(Fraction(
					tonumber(measure_numerators[measure_cursor]),
					tonumber(measure_denominators[measure_cursor])
				))
				point._measure = measure
				measure_cursor = measure_cursor + 1
			end
			point.tempo = tempo
			point.measure = measure
			if not continue_restore() then return end
		end

		for _, snapshot_visual in ipairs(snapshot_layer.visuals) do
			local visual = Visual()
			layer.visuals[snapshot_visual.name] = visual
			visual.primaryTempo = snapshot_visual.primary_tempo
			visual.tempoMultiplyTarget = snapshot_visual.tempo_multiply_target
			visual.bga = snapshot_visual.bga

			local point_indexes = PrimitiveArray.uint32(snapshot_visual.point_indexes)
			local velocity_indexes = PrimitiveArray.uint32(snapshot_visual.velocity_indexes)
			local velocities = PrimitiveArray.doubles(snapshot_visual.velocities)
			local expand_indexes = PrimitiveArray.uint32(snapshot_visual.expand_indexes)
			local expands = PrimitiveArray.doubles(snapshot_visual.expands)
			local visual_times = PrimitiveArray.doubles(snapshot_visual.visual_times)
			local monotonic_visual_times = PrimitiveArray.doubles(snapshot_visual.monotonic_visual_times)
			local sections = PrimitiveArray.int32(snapshot_visual.sections)
			local current_speeds = PrimitiveArray.doubles(snapshot_visual.current_speeds)
			local local_speeds = PrimitiveArray.doubles(snapshot_visual.local_speeds)
			local global_speeds = PrimitiveArray.doubles(snapshot_visual.global_speeds)
			---@type {[chart.Point]: integer}
			local point_index_map = {}
			visual.point_index = point_index_map
			local velocity_cursor = 0
			local expand_cursor = 0
			for visual_offset = 0, snapshot_visual.point_count - 1 do
				local visual_index = visual_offset + 1
				local point_index = tonumber(point_indexes[visual_offset])
				local point = points[point_index]
				local visual_point = visual:newPoint(point)
				table.insert(visual_points, visual_point)
				if not point_index_map[point] then
					point_index_map[point] = visual_index
				end
				if velocity_cursor < snapshot_visual.velocity_count and tonumber(velocity_indexes[velocity_cursor]) == visual_index then
					local value_offset = velocity_cursor * 3
					visual_point._velocity = Velocity(
						tonumber(velocities[value_offset]),
						tonumber(velocities[value_offset + 1]),
						tonumber(velocities[value_offset + 2])
					)
					velocity_cursor = velocity_cursor + 1
				end
				if expand_cursor < snapshot_visual.expand_count and tonumber(expand_indexes[expand_cursor]) == visual_index then
					visual_point._expand = Expand(tonumber(expands[expand_cursor]))
					expand_cursor = expand_cursor + 1
				end
				visual_point.visualTime = tonumber(visual_times[visual_offset])
				visual_point.monotonicVisualTime = tonumber(monotonic_visual_times[visual_offset])
				visual_point.section = tonumber(sections[visual_offset])
				visual_point:setSpeeds(
					tonumber(current_speeds[visual_offset]),
					tonumber(local_speeds[visual_offset]),
					tonumber(global_speeds[visual_offset])
				)
				if not continue_restore() then return end
			end
		end
	end

	local snapshot_notes = snapshot.notes
	local note_point_indexes = PrimitiveArray.uint32(snapshot_notes.point_indexes)
	local note_column_indexes = PrimitiveArray.uint16(snapshot_notes.column_indexes)
	local note_type_indexes = PrimitiveArray.uint16(snapshot_notes.type_indexes)
	local note_weights = PrimitiveArray.int8(snapshot_notes.weights)
	local linked_notes = chart.notes.linked_notes
	---@type {[chart.Column]: {[chart.NoteType]: integer[]}}
	local link_stacks = {}
	for note_offset = 0, snapshot_notes.count - 1 do
		local note_index = note_offset + 1
		local note = Note(
			visual_points[tonumber(note_point_indexes[note_offset])],
			snapshot_notes.columns[tonumber(note_column_indexes[note_offset])],
			snapshot_notes.types[tonumber(note_type_indexes[note_offset])],
			tonumber(note_weights[note_offset]),
			table_util.deepcopy(snapshot_notes.data[note_index])
		)
		chart.notes:insert(note)

		local weight = note.weight
		if weight == 0 then
			table.insert(linked_notes, LinkedNote(note))
		elseif weight == 1 then
			table.insert(linked_notes, LinkedNote(note))
			local column = note.column
			local note_type = note.type
			link_stacks[column] = link_stacks[column] or {}
			link_stacks[column][note_type] = link_stacks[column][note_type] or {}
			table.insert(link_stacks[column][note_type], #linked_notes)
		elseif weight == -1 then
			local stack = assert(link_stacks[note.column][note.type])
			local linked_index = assert(table.remove(stack))
			linked_notes[linked_index].endNote = note
		end
		if not continue_restore() then return end
	end

	for _, resource in ipairs(snapshot.resources) do
		chart.resources:add(unpack(resource))
	end
	if checkpoint and checkpoint() == false then return end
	return chart
end

return SnapshotRestorer
