local ShortNoteView = require("sphere.views.RhythmView.ShortNoteView")
local gfx_util = require("gfx_util")

---@class sphere.LongNoteView: sphere.ShortNoteView
---@operator call: sphere.LongNoteView
local LongNoteView = ShortNoteView + {}

function LongNoteView:draw()
	local headView = self:getNotePart("Head")
	local bodyView = self:getNotePart("Body")
	local tailView = self:getNotePart("Tail")

	local headSpriteBatch = headView:getSpriteBatch()
	local bodySpriteBatch = bodyView:getSpriteBatch()
	local tailSpriteBatch = tailView:getSpriteBatch()

	self.bodyQuad = self.bodyQuad or love.graphics.newQuad(0, 0, 1, 1, 1, 1)
	if bodySpriteBatch then
		bodySpriteBatch:setColor(bodyView:getColor())
		bodySpriteBatch:add(self.bodyQuad, self:getBodyTransformParams())
	end
	if tailSpriteBatch then
		tailSpriteBatch:setColor(tailView:getColor())
		tailSpriteBatch:add(self:getDraw(tailView:getQuad(), self:getTailTransformParams()))
	end
	if headSpriteBatch then
		headSpriteBatch:setColor(headView:getColor())
		headSpriteBatch:add(self:getDraw(headView:getQuad(), self:getHeadTransformParams()))
	end

	local hw = self:getNotePart("Head")
	local tw = self:getNotePart("Tail")

	local note = self.graphicalNote

	if headSpriteBatch then
		local tf = gfx_util.transform(self:getHeadTransformParams())
		local w, h = hw:getDimensions()
		note.headOver = self:isMouseOverPart(tf, w, h)
		note.headSelecting = self:isSelectedPart(tf, w, h)
	end

	if tailSpriteBatch then
		local tf = gfx_util.transform(self:getTailTransformParams())
		local w, h = tw:getDimensions()
		note.tailOver = self:isMouseOverPart(tf, w, h)
		note.tailSelecting = self:isSelectedPart(tf, w, h)
	end

	if bodySpriteBatch then
		local tf = gfx_util.transform(self:getBodyTransformParams())
		local _, _, w, h = self.bodyQuad:getViewport()
		note.bodyOver = self:isMouseOverPart(tf, w, h)
		note.bodySelecting = self:isSelectedPart(tf, w, h)
	end

	self.graphicalNote.over = note.headOver or note.tailOver or note.bodyOver
	self.graphicalNote.selecting = note.headSelecting or note.tailSelecting or note.bodySelecting
end

function LongNoteView:drawSelected()
	local hw = self:getNotePart("Head")
	local w, h = hw:getDimensions()

	local tf = gfx_util.transform(self:getTransformParams())
	local x, y = tf:transformPoint(0, 0)
	local _w, _h = tf:transformPoint(w, h)

	local tw = self:getNotePart("Tail")
	local w, h = tw:getDimensions()

	local tf = gfx_util.transform(self:getTailTransformParams())
	local x1, y1 = tf:transformPoint(0, 0)
	local _w1, _h1 = tf:transformPoint(w, h)

	local ymin = math.min(y, _h, y1, _h1)
	local ymax = math.max(y, _h, y1, _h1)

	local a = (math.sin(love.timer.getTime() * 2) + 1) / 2
	local b = (math.sin(love.timer.getTime() * 2 + math.pi * 2 / 3) + 1) / 2
	local c = (math.sin(love.timer.getTime() * 2 + math.pi * 4 / 3) + 1) / 2

	love.graphics.setColor(a, b, c, 0.2)
	love.graphics.rectangle("fill", x, ymin, _w - x, ymax - ymin)
	love.graphics.setColor(a, b, c)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, ymin, _w - x, ymax - ymin)
	love.graphics.setLineWidth(1)
	love.graphics.setColor(1, 1, 1)
end

---@param chords table
---@param column number
function LongNoteView:fillChords(chords, column)
	local note = self.graphicalNote.linked_note
	local startNote = note.startNote
	local endNote = note.endNote

	if startNote then
		local time = startNote:getTime()
		chords[time] = chords[time] or {}
		local chord = chords[time]
		chord[column] = chord[column] or {}
		table.insert(chord[column], self.graphicalNote)
	end

	if endNote then
		local time = endNote:getTime()
		chords[time] = chords[time] or {}
		local chord = chords[time]
		chord[column] = chord[column] or {}
		table.insert(chord[column], self.graphicalNote)
	end
end

LongNoteView.getHeadTransformParams = LongNoteView.getTransformParams

---@return number?...
function LongNoteView:getTailTransformParams()
	local tw = self:getNotePart("Tail")
	local ets = {dt = self.graphicalNote.end_dt}
	local w, h = tw:getDimensions()
	local nw, nh = tw:get("w", ets), tw:get("h", ets)
	local sx = nw and nw / w or tw:get("sx", ets) or 1
	local sy = nh and nh / h or tw:get("sy", ets) or 1
	local ox = (tw:get("ox", ets) or 0) * w
	local oy = (tw:get("oy", ets) or 0) * h
	return
		tw:get("x", ets),
		tw:get("y", ets),
		tw:get("r", ets) or 0,
		sx,
		sy,
		ox,
		oy
end

---@return number?...
function LongNoteView:getBodyTransformParams()
	local hw = self:getNotePart("Head")
	local tw = self:getNotePart("Tail")
	local bw = self:getNotePart("Body")

	local sts = {dt = self.graphicalNote.start_dt}
	local ets = {dt = self.graphicalNote.end_dt}

	local dx = hw:get("x", sts) - tw:get("x", ets)
	local dy = hw:get("y", sts) - tw:get("y", ets)

	local w, h = bw:getDimensions()
	local nw, nh = bw:get("w"), bw:get("h")

	local sx = nw and nw / w or bw:get("sx") or 1
	-- local sx = nw and (dx + nw) / w or bw:get("sx") or 1

	local style = bw:get("style")
	local sy = bw:get("scale") or sx  -- "cascade_top"
	if style == "stretch" then
		sy = nh and (dy + nh) / h or bw:get("sy") or 1
	end

	local height = dy / sy

	local y = bw:get("y", ets)
	if style == "cascade_bottom" then
		y = bw:get("y", sts)
		height = -height
	end

	self.bodyQuad:setViewport(0, 0, w, height, w, h)

	local ox = (bw:get("ox") or 0) * w
	local oy = (bw:get("oy") or 0) * h
	return
		bw:get("x", ets),
		y,
		0,
		sx,
		sy,
		ox,
		oy
end

return LongNoteView
