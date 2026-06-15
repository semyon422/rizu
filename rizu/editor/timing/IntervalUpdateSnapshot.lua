---@class rizu.editor.IntervalUpdateSnapshot.RemovedPoint
---@field vertex chartedit.Vertex
---@field time chart.Fraction
---@field notes chart.Note[]?

local IntervalUpdateSnapshot = {}

---@param vertex chartedit.Vertex
---@param beats number
---@param min_beat_duration number
---@return number?
local function getClampedBeats(vertex, beats, min_beat_duration)
	local next_vertex = vertex.next
	if not next_vertex then
		return
	end

	assert(math.floor(beats) == beats)
	beats = math.max(beats, vertex:start() >= next_vertex:start() and 1 or 0)

	local max_beats = (next_vertex.point.absoluteTime - vertex.point.absoluteTime) / min_beat_duration
		+ vertex:start()
		- next_vertex:start()
	return math.min(beats, math.floor(max_beats))
end

---@param note_storage chartedit.Notes
---@param point chartedit.Point
---@return chart.Note[]?
local function collectPointNotes(note_storage, point)
	---@type chart.Note[]
	local notes = {}
	for note in note_storage:iter() do
		if note.visualPoint.point == point then
			table.insert(notes, note)
		end
	end
	if not notes[1] then
		return
	end
	return notes
end

---@param context rizu.editor.IntervalManagerContext
---@param vertex chartedit.Vertex
---@param beats number
---@return rizu.editor.IntervalUpdateSnapshot.RemovedPoint[]?
function IntervalUpdateSnapshot.captureRemovedPoints(context, vertex, beats)
	local layer = context:getLayer()
	beats = getClampedBeats(vertex, beats, layer.vertices.minBeatDuration)
	if not beats or beats >= vertex.beats then
		return
	end

	local next_vertex = vertex.next
	local point = next_vertex.point.prev
	local threshold = next_vertex:start() + beats
	---@type rizu.editor.IntervalUpdateSnapshot.RemovedPoint[]
	local removed_points = {}

	while point and point ~= vertex.point and point.time >= threshold do
		table.insert(removed_points, {
			vertex = point.vertex,
			time = point.time,
			notes = collectPointNotes(context:getNotes(), point),
		})
		point = point.prev
	end

	if not removed_points[1] then
		return
	end
	return removed_points
end

---@param note_storage chartedit.Notes
---@param removed_points rizu.editor.IntervalUpdateSnapshot.RemovedPoint[]?
function IntervalUpdateSnapshot.removeNotes(note_storage, removed_points)
	for _, removed_point in ipairs(removed_points or {}) do
		for _, note in ipairs(removed_point.notes or {}) do
			if note_storage:findNote(note) then
				note_storage:removeNote(note)
			end
		end
	end
end

---@param context rizu.editor.IntervalManagerContext
---@param removed_points rizu.editor.IntervalUpdateSnapshot.RemovedPoint[]?
function IntervalUpdateSnapshot.restore(context, removed_points)
	if not removed_points then
		return
	end

	local layer = context:getLayer()
	local note_storage = context:getNotes()
	for _, removed_point in ipairs(removed_points) do
		local point = layer.points:getPoint(removed_point.vertex, removed_point.time)
		local visual_point
		for _, visual in pairs(layer.visuals) do
			local vp = visual:getPoint(point)
			visual_point = visual_point or vp
		end
		for _, note in ipairs(removed_point.notes or {}) do
			note.visualPoint = assert(visual_point)
			if not note_storage:findNote(note) then
				note_storage:addNote(note)
			end
		end
	end
end

return IntervalUpdateSnapshot
