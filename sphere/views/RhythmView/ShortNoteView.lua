local NoteView = require("sphere.views.RhythmView.NoteView")
local gfx_util = require("gfx_util")

---@class sphere.ShortNoteView: sphere.NoteView
---@operator call: sphere.ShortNoteView
local ShortNoteView = NoteView + {}

function ShortNoteView:draw()
	local headView = self:getNotePart("Head")
	local spriteBatch = headView:getSpriteBatch()
	if not spriteBatch then
		return
	end
	spriteBatch:setColor(headView:getColor())
	spriteBatch:add(self:getDraw(headView:getQuad(), self:getTransformParams()))

	local hw = self:getNotePart("Head")
	local w, h = hw:getDimensions()
end

function ShortNoteView:drawSelected()
	local hw = self:getNotePart("Head")
	local w, h = hw:getDimensions()

	local tf = gfx_util.transform(self:getTransformParams())
	local x, y = tf:transformPoint(0, 0)
	local _w, _h = tf:transformPoint(w, h)

	local a = (math.sin(love.timer.getTime() * 2) + 1) / 2
	local b = (math.sin(love.timer.getTime() * 2 + math.pi * 2 / 3) + 1) / 2
	local c = (math.sin(love.timer.getTime() * 2 + math.pi * 4 / 3) + 1) / 2

	love.graphics.setColor(a, b, c, 0.2)
	love.graphics.rectangle("fill", x, y, _w - x, _h - y)
	love.graphics.setColor(a, b, c)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, _w - x, _h - y)
	love.graphics.setLineWidth(1)
	love.graphics.setColor(1, 1, 1)
end

---@param chords table
---@param column number
function ShortNoteView:fillChords(chords, column)
	local time = self.graphicalNote.linked_note.startNote:getTime()

	chords[time] = chords[time] or {}
	local chord = chords[time]
	chord[column] = chord[column] or {}
	table.insert(chord[column], self.graphicalNote)
end

---@return boolean
function ShortNoteView:isVisible()
	local color = self:getNotePart("Head"):getColor()
	if not color then
		return false
	end
	return color[4] > 0
end

---@return number?...
function ShortNoteView:getTransformParams()
	local hw = self:getNotePart("Head")
	local w, h = hw:getDimensions()
	local nw, nh = hw:get("w"), hw:get("h")
	local sx = nw and nw / w or hw:get("sx") or 1
	local sy = nh and nh / h or hw:get("sy") or 1
	local ox = (hw:get("ox") or 0) * w
	local oy = (hw:get("oy") or 0) * h
	return
		hw:get("x"),
		hw:get("y"),
		hw:get("r") or 0,
		sx,
		sy,
		ox,
		oy
end

return ShortNoteView
