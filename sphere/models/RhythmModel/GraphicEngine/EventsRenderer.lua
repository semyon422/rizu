local class = require("class")
local table_util = require("table_util")
local GraphicalNoteFactory = require("sphere.models.RhythmModel.GraphicEngine.GraphicalNoteFactory")
local Point = require("chart.model.tp.Point")
local VisualPoint = require("chart.model.visual.VisualPoint")

---@class sphere.EventsRenderer
---@operator call: sphere.EventsRenderer
local EventsRenderer = class()

local function sort_const(a, b)
	return a.startNote.visualPoint.point:compare(b.startNote.visualPoint.point)
end

---@param chart ncdk2.Chart
---@param graphicEngine sphere.GraphicEngine
function EventsRenderer:new(chart, graphicEngine)
	self.chart = chart
	self.graphicEngine = graphicEngine
end

function EventsRenderer:insertNoteEvent(vp, note, show, hide)
	self.note_events[vp] = self.note_events[vp] or {}
	table.insert(self.note_events[vp], {
		note = note,
		show = show,
		hide = hide,
	})
end

function EventsRenderer:load()
	local graphicEngine = self.graphicEngine
	local chart = self.chart

	---@type {[ncdk2.Visual]: ncdk2.VisualPoint}
	self.cvp = {}

	for _, visual in ipairs(self.chart:getVisuals()) do
		self.cvp[visual] = VisualPoint(Point())
		visual:generateEvents()
	end

	---@type {[ncdk2.VisualPoint]: -1|1}
	self.point_events = {}

	local point_events = self.point_events
	function self.handle_event(vp, action)
		point_events[vp] = action
	end

	self.note_events = {}

	for _, _note in ipairs(chart.notes:getLinkedNotes()) do
		local note = GraphicalNoteFactory:getNote(_note)
		if note then
			local visual = chart:getVisualByPoint(_note.startNote.visualPoint)
			note.currentVisualPoint = self.cvp[visual]
			note.visual = visual
			note.graphicEngine = graphicEngine
			note.column = _note:getColumn()

			local endNote = note.endNote
			if not endNote then
				self:insertNoteEvent(note.startNote.visualPoint, note, true, true)
			else
				self:insertNoteEvent(note.startNote.visualPoint, note, true, false)
				self:insertNoteEvent(endNote.visualPoint, note, false, true)
			end
		end
	end

	self.visible_notes_map = {}
	self.visible_notes = {}
end

function EventsRenderer:update()
	local graphicEngine = self.graphicEngine
	local currentTime = graphicEngine:getCurrentTime()

	local point_events = self.point_events
	local handle_event = self.handle_event

	-- TODO: fix a bug with LN disappearing
	-- when you increase play speed and LN tail get hide event

	for _, visual in ipairs(self.chart:getVisuals()) do
		local cvp = self.cvp[visual]
		cvp.point.absoluteTime = currentTime - graphicEngine:getInputOffset()
		visual.interpolator:interpolate(visual.points, cvp, "absolute")

		local visualTimeRate = graphicEngine.visualTimeRate * cvp.globalSpeed
		local range = math.max(-graphicEngine.range[1], graphicEngine.range[2]) / visualTimeRate

		table_util.clear(point_events)
		visual.scroller:scroll(cvp.point.absoluteTime, handle_event)
		visual.scroller:scale(range, handle_event)

		for vp, action in pairs(point_events) do
			local es = self.note_events[vp]
			if es then
				for _, e in ipairs(es) do
					if action == 1 and e.show then
						self.visible_notes_map[e.note] = true
					elseif action == -1 and e.hide then
						self.visible_notes_map[e.note] = nil
					end
				end
			end
		end
	end

	local visible_notes = self.visible_notes
	table_util.clear(visible_notes)

	for note in pairs(self.visible_notes_map) do
		note:update()
		table.insert(visible_notes, note)
	end

	table.sort(visible_notes, sort_const)
end

---@generic T
---@param f fun(obj: T, note: sphere.GraphicalNote)
---@param obj T
function EventsRenderer:iterNotes(f, obj)
	for _, note in ipairs(self.visible_notes) do
		f(obj, note)
	end
end

return EventsRenderer
