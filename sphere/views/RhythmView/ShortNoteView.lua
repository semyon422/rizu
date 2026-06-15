local NoteView = require("sphere.views.RhythmView.NoteView")
local gfx_util = require("gfx_util")

---@class sphere.ShortNoteView: sphere.NoteView
---@operator call: sphere.ShortNoteView
local ShortNoteView = NoteView + {}

---@param tf love.Transform
---@param w number
---@param h number
---@return boolean
local function isMouseOver(tf, w, h)
	local x, y = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	x, y = tf:inverseTransformPoint(x, y)
	return x >= 0 and x <= w and y >= 0 and y <= h
end

---@param rect number[]?
---@param tf love.Transform
---@param w number
---@param h number
---@return boolean
local function isSelectedByRect(rect, tf, w, h)
	if not rect then
		return false
	end

	local x0, y0 = tf:transformPoint(0, 0)
	local x1, y1 = tf:transformPoint(w, h)
	local noteLeft = math.min(x0, x1)
	local noteRight = math.max(x0, x1)
	local noteTop = math.min(y0, y1)
	local noteBottom = math.max(y0, y1)

	local rectLeft = math.min(rect[1], rect[3])
	local rectRight = math.max(rect[1], rect[3])
	local rectTop = math.min(rect[2], rect[4])
	local rectBottom = math.max(rect[2], rect[4])

	return noteLeft <= rectRight and noteRight >= rectLeft and noteTop <= rectBottom and noteBottom >= rectTop
end

---@return number[]?
function ShortNoteView:getSelectionRect()
	local rhythmView = self.rhythmView
	local game = rhythmView and rhythmView.game
	local editorModel = game and game.editorModel
	if not editorModel then
		return
	end
	return editorModel:getSelectionState():getRect()
end

---@param tf love.Transform
---@param w number
---@param h number
---@return boolean
function ShortNoteView:isMouseOverPart(tf, w, h)
	return isMouseOver(tf, w, h)
end

---@param tf love.Transform
---@param w number
---@param h number
---@return boolean
function ShortNoteView:isSelectedPart(tf, w, h)
	return isSelectedByRect(self:getSelectionRect(), tf, w, h)
end

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

	local tf = gfx_util.transform(self:getTransformParams())

	self.graphicalNote.over = self:isMouseOverPart(tf, w, h)
	self.graphicalNote.selecting = self:isSelectedPart(tf, w, h)
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
