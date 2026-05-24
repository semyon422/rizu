local class = require("class")
local table_util = require("table_util")
local VisualNoteFactory = require("rizu.engine.visual.VisualNoteFactory")
local Point = require("chart.model.tp.Point")
local VisualPoint = require("chart.model.visual.VisualPoint")

---@class rizu.VisualEngine
---@operator call: rizu.VisualEngine
local VisualEngine = class()

VisualEngine.range = 1

---@param action -1|1
---@return true?
local function true_from_action(action)
	if action == 1 then
		return true
	end
end

---@param visual_info rizu.VisualInfo
function VisualEngine:new(visual_info)
	self.visual_info = visual_info
	self.visual_note_factory = VisualNoteFactory(visual_info)
end

---@param vp any
---@param event table
function VisualEngine:insertNoteEvent(vp, event)
	self.point_notes[vp] = self.point_notes[vp] or {}
	table.insert(self.point_notes[vp], event)
end

---@param linked_note ncdk2.LinkedNote
---@param visual_note rizu.VisualNote
function VisualEngine:addNote(linked_note, visual_note)
	local event = {
		linked_note = linked_note,
		visual_note = visual_note,
	}

	self:insertNoteEvent(linked_note.startNote.visualPoint, event)
	if linked_note:isLong() then
		self:insertNoteEvent(linked_note.endNote.visualPoint, event)
	end
end

---@param chart ncdk2.Chart
---@param lazy_scrollers boolean?
function VisualEngine:load(chart, lazy_scrollers)
	---@type {[ncdk2.Visual]: ncdk2.VisualPoint}
	self.cvp = {}

	---@type {[rizu.VisualNote]: true}
	self.visible_notes_map = {}
	---@type rizu.VisualNote[]
	self.visible_notes = {}

	---@type {[ncdk2.VisualPoint]: -1|1}
	self.point_events = {}
	---@type {[ncdk2.VisualPoint]: {linked_note: ncdk2.LinkedNote, visual_note: rizu.VisualNote}[]}
	self.point_notes = {}

	for _, visual in ipairs(chart:getVisuals()) do
		self.cvp[visual] = VisualPoint(Point())
		visual:generateEvents(lazy_scrollers)
	end

	local point_events = self.point_events
	function self.handle_event(vp, action)
		point_events[vp] = action
	end

	for _, linked_note in ipairs(chart.notes:getLinkedNotes()) do
		local visual = chart:getVisualByPoint(linked_note.startNote.visualPoint --[[@as ncdk2.VisualPoint]])
		if visual and not visual.bga then
			local visual_note = self.visual_note_factory:getNote(linked_note)
			if visual_note then
				visual_note.cvp = self.cvp[visual]
				visual_note.visual = visual

				self:addNote(linked_note, visual_note)
			end
		end
	end
end

function VisualEngine:update()
	local time = self.visual_info:getTime()

	table_util.clear(self.point_events)

	self:_updateInterpolation(time)
	self:_updateScrollers(time)
	self:_updateEventProcessing()
	self:_updateVisibleNotes()
end

---@param time number
function VisualEngine:_updateInterpolation(time)
	for visual, cvp in pairs(self.cvp) do
		cvp.point.absoluteTime = time
		visual.interpolator:interpolate(visual.points, cvp, "absolute")
	end
end

---@param time number
function VisualEngine:_updateScrollers(time)
	local range = self.range
	local visual_info = self.visual_info
	local handle_event = self.handle_event

	for visual, cvp in pairs(self.cvp) do
		-- TODO: implement const for scroller
		visual.scroller:scroll(time, handle_event)
		visual.scroller:scale(range / (visual_info.rate * cvp.globalSpeed), handle_event)
	end
end

function VisualEngine:_updateEventProcessing()
	local point_events = self.point_events
	local visible_notes_map = self.visible_notes_map

	-- TODO: fix a bug with LN disappearing
	-- when you increase play speed and LN tail get hide event
	for vp, action in pairs(point_events) do
		local notes = self.point_notes[vp]
		if notes then
			for _, t in ipairs(notes) do
				if
					t.linked_note:isShort() or
					vp == t.linked_note.startNote.visualPoint and action == 1 or
					vp == t.linked_note.endNote.visualPoint and action == -1
				then
					visible_notes_map[t.visual_note] = true_from_action(action)
				end
			end
		end
	end
end

function VisualEngine:_updateVisibleNotes()
	local visible_notes = self.visible_notes
	table_util.clear(visible_notes)

	for note in pairs(self.visible_notes_map) do
		note:update()
		table.insert(visible_notes, note)
	end

	table.sort(visible_notes)
end

return VisualEngine
