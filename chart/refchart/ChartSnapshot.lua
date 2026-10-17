local class = require("class")
local table_util = require("table_util")
local PrimitiveArray = require("chart.refchart.PrimitiveArray")

---@class refchart.ChartSnapshotVisual
---@field name string
---@field primary_tempo number
---@field tempo_multiply_target "none"|"current"|"local"|"global"
---@field bga boolean?
---@field point_count integer
---@field point_indexes string Packed uint32 values.
---@field velocity_count integer
---@field velocity_indexes string Packed uint32 values.
---@field velocities string Packed double current, local, and global speeds.
---@field expand_count integer
---@field expand_indexes string Packed uint32 values.
---@field expands string Packed double values.
---@field visual_times string Packed double values.
---@field monotonic_visual_times string Packed double values.
---@field sections string Packed int32 values.
---@field current_speeds string Packed double values.
---@field local_speeds string Packed double values.
---@field global_speeds string Packed double values.

---@class refchart.ChartSnapshotLayer
---@field name string
---@field point_count integer
---@field point_times string Packed double values.
---@field tempo_count integer
---@field tempo_indexes string Packed uint32 values.
---@field tempos string Packed double values.
---@field measure_count integer
---@field measure_indexes string Packed uint32 values.
---@field measure_numerators string Packed double values.
---@field measure_denominators string Packed double values.
---@field visuals refchart.ChartSnapshotVisual[]

---@class refchart.ChartSnapshotNotes
---@field count integer
---@field point_indexes string Packed uint32 values.
---@field column_indexes string Packed uint16 values.
---@field columns chart.Column[]
---@field type_indexes string Packed uint16 values.
---@field types chart.NoteType[]
---@field weights string Packed int8 values.
---@field data {[integer]: table} Only non-empty note data is stored.

---@class refchart.ChartSnapshot
---@operator call: refchart.ChartSnapshot
---@field data table
---@field inputmode {[string]: integer}
---@field layers refchart.ChartSnapshotLayer[]
---@field notes refchart.ChartSnapshotNotes
---@field resources {[1]: chart.ResourceType, [integer]: string}[]
local ChartSnapshot = class()

---@param t {[string]: any}
---@return string[]
local function sorted_keys(t)
	local keys = {}
	for key in pairs(t) do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

---@param values string[]
---@param indexes {[string]: integer}
---@param value string
---@return integer
local function intern(values, indexes, value)
	local index = indexes[value]
	if index then
		return index
	end
	index = #values + 1
	values[index] = value
	indexes[value] = index
	return index
end

---@param chart chart.Chart
function ChartSnapshot:new(chart)
	self.inputmode = table_util.copy(chart.inputMode)
	self.data = table_util.deepcopy(chart.data)

	---@type {[chart.VisualPoint]: integer}
	local visual_point_indexes = {}
	local visual_point_count = 0

	---@type refchart.ChartSnapshotLayer[]
	self.layers = {}
	for _, layer_name in ipairs(sorted_keys(chart.layers)) do
		local layer = chart.layers[layer_name]
		---@type chart.AbsolutePoint[]
		local points = layer:getPointList()
		---@type {[chart.AbsolutePoint]: integer}
		local point_indexes = {}
		---@type number[]
		local point_times = {}
		---@type integer[]
		local tempo_indexes = {}
		---@type number[]
		local tempos = {}
		---@type integer[]
		local measure_indexes = {}
		---@type integer[]
		local measure_numerators = {}
		---@type integer[]
		local measure_denominators = {}

		for point_index, point in ipairs(points) do
			point_indexes[point] = point_index
			point_times[point_index] = point.absoluteTime
			if point._tempo then
				table.insert(tempo_indexes, point_index)
				table.insert(tempos, point._tempo.tempo)
			end
			if point._measure then
				local offset = point._measure.offset
				table.insert(measure_indexes, point_index)
				table.insert(measure_numerators, offset[1])
				table.insert(measure_denominators, offset[2])
			end
		end

		---@type refchart.ChartSnapshotLayer
		local snapshot_layer = {
			name = layer_name,
			point_count = #point_times,
			point_times = PrimitiveArray.packDoubles(point_times),
			tempo_count = #tempo_indexes,
			tempo_indexes = PrimitiveArray.packUint32(tempo_indexes),
			tempos = PrimitiveArray.packDoubles(tempos),
			measure_count = #measure_indexes,
			measure_indexes = PrimitiveArray.packUint32(measure_indexes),
			measure_numerators = PrimitiveArray.packDoubles(measure_numerators),
			measure_denominators = PrimitiveArray.packDoubles(measure_denominators),
			visuals = {},
		}
		table.insert(self.layers, snapshot_layer)

		for _, visual_name in ipairs(sorted_keys(layer.visuals)) do
			local visual = layer.visuals[visual_name]
			---@type integer[]
			local visual_point_point_indexes = {}
			---@type integer[]
			local velocity_indexes = {}
			---@type number[]
			local velocities = {}
			---@type integer[]
			local expand_indexes = {}
			---@type number[]
			local expands = {}
			---@type number[]
			local visual_times = {}
			---@type number[]
			local monotonic_visual_times = {}
			---@type integer[]
			local sections = {}
			---@type number[]
			local current_speeds = {}
			---@type number[]
			local local_speeds = {}
			---@type number[]
			local global_speeds = {}

			for visual_index, visual_point in ipairs(visual.points) do
				visual_point_count = visual_point_count + 1
				visual_point_indexes[visual_point] = visual_point_count
				visual_point_point_indexes[visual_index] = assert(point_indexes[visual_point.point])
				local velocity = visual_point._velocity
				if velocity then
					table.insert(velocity_indexes, visual_index)
					table.insert(velocities, velocity.currentSpeed)
					table.insert(velocities, velocity.localSpeed)
					table.insert(velocities, velocity.globalSpeed)
				end
				local expand = visual_point._expand
				if expand then
					table.insert(expand_indexes, visual_index)
					table.insert(expands, expand.duration)
				end
				visual_times[visual_index] = visual_point.visualTime
				monotonic_visual_times[visual_index] = visual_point.monotonicVisualTime
				sections[visual_index] = visual_point.section
				current_speeds[visual_index] = visual_point.currentSpeed
				local_speeds[visual_index] = visual_point.localSpeed
				global_speeds[visual_index] = visual_point.globalSpeed
			end

			---@type refchart.ChartSnapshotVisual
			local snapshot_visual = {
				name = visual_name,
				primary_tempo = visual.primaryTempo,
				tempo_multiply_target = visual.tempoMultiplyTarget,
				bga = visual.bga or nil,
				point_count = #visual_point_point_indexes,
				point_indexes = PrimitiveArray.packUint32(visual_point_point_indexes),
				velocity_count = #velocity_indexes,
				velocity_indexes = PrimitiveArray.packUint32(velocity_indexes),
				velocities = PrimitiveArray.packDoubles(velocities),
				expand_count = #expand_indexes,
				expand_indexes = PrimitiveArray.packUint32(expand_indexes),
				expands = PrimitiveArray.packDoubles(expands),
				visual_times = PrimitiveArray.packDoubles(visual_times),
				monotonic_visual_times = PrimitiveArray.packDoubles(monotonic_visual_times),
				sections = PrimitiveArray.packInt32(sections),
				current_speeds = PrimitiveArray.packDoubles(current_speeds),
				local_speeds = PrimitiveArray.packDoubles(local_speeds),
				global_speeds = PrimitiveArray.packDoubles(global_speeds),
			}
			table.insert(snapshot_layer.visuals, snapshot_visual)
		end
	end

	---@type integer[]
	local note_point_indexes = {}
	---@type integer[]
	local note_column_indexes = {}
	---@type chart.Column[]
	local columns = {}
	---@type integer[]
	local note_type_indexes = {}
	---@type chart.NoteType[]
	local types = {}
	---@type integer[]
	local weights = {}
	---@type {[integer]: table}
	local note_data = {}
	---@type {[string]: integer}
	local column_indexes = {}
	---@type {[string]: integer}
	local type_indexes = {}
	for note_index, note in ipairs(chart.notes.notes) do
		note_point_indexes[note_index] = assert(visual_point_indexes[note.visualPoint])
		note_column_indexes[note_index] = intern(columns, column_indexes, note.column)
		note_type_indexes[note_index] = intern(types, type_indexes, note.type)
		weights[note_index] = note.weight
		if next(note.data) then
			note_data[note_index] = table_util.deepcopy(note.data)
		end
	end

	self.notes = {
		count = #note_point_indexes,
		point_indexes = PrimitiveArray.packUint32(note_point_indexes),
		column_indexes = PrimitiveArray.packUint16(note_column_indexes),
		columns = columns,
		type_indexes = PrimitiveArray.packUint16(note_type_indexes),
		types = types,
		weights = PrimitiveArray.packInt8(weights),
		data = note_data,
	}

	self.resources = {}
	for resource_type, paths in chart.resources:iter() do
		table.insert(self.resources, {resource_type, unpack(paths)})
	end
end

return ChartSnapshot
