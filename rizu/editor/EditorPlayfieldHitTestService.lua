local class = require("class")

---@alias rizu.editor.EditorPlayfieldMouseOverFunc fun(id: any, over: boolean, layer: string): boolean
---@alias rizu.editor.EditorPlayfieldIsOverFunc fun(w: number, h: number, x?: number, y?: number): boolean

---@class rizu.editor.EditorPlayfieldHitTestServiceDeps
---@field mouseOver rizu.editor.EditorPlayfieldMouseOverFunc?
---@field isOver rizu.editor.EditorPlayfieldIsOverFunc?

---@class rizu.editor.EditorPlayfieldHitTestService
---@operator call: rizu.editor.EditorPlayfieldHitTestService
---@field mouseOver rizu.editor.EditorPlayfieldMouseOverFunc
---@field isOver rizu.editor.EditorPlayfieldIsOverFunc
local EditorPlayfieldHitTestService = class()

---@param deps rizu.editor.EditorPlayfieldHitTestServiceDeps?
function EditorPlayfieldHitTestService:new(deps)
	deps = deps or {}
	self.mouseOver = deps.mouseOver or function(_, over)
		return over
	end
	self.isOver = deps.isOver or function(w, h, x, y)
		local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
		x = x or 0
		y = y or 0
		return mx >= x and mx <= x + w and my >= y and my <= y + h
	end
end

---@param note sphere.GraphicalNote
---@param mouseTime number
---@param inputState rizu.editor.EditorPlayfieldInputState
---@return rizu.editor.EditorPlayfieldNoteInput?
function EditorPlayfieldHitTestService:getNoteInput(note, mouseTime, inputState)
	if note.noteType == "ShortNote" then
		return {
			note = note,
			mouseTime = mouseTime,
			leftPressed = inputState.leftPressed,
			rightPressed = inputState.rightPressed,
			bodyOver = self.mouseOver(note, note.over, "mouse"),
		}
	elseif note.noteType == "LongNote" then
		return {
			note = note,
			mouseTime = mouseTime,
			leftPressed = inputState.leftPressed,
			rightPressed = inputState.rightPressed,
			bodyOver = self.mouseOver(tostring(note) .. "body", note.bodyOver, "mouse"),
			headOver = self.mouseOver(tostring(note) .. "head", note.headOver, "mouse"),
			tailOver = self.mouseOver(tostring(note) .. "tail", note.tailOver, "mouse"),
		}
	end
end

---@param noteSkin table
---@param head table
---@param columnIndex integer
---@param time number
---@param inputState rizu.editor.EditorPlayfieldInputState
---@return rizu.editor.EditorPlayfieldColumnInput
function EditorPlayfieldHitTestService:getColumnInput(noteSkin, head, columnIndex, time, inputState)
	local x = noteSkin:getValue(head.x, columnIndex)
	local w = noteSkin:getValue(head.w, columnIndex)
	local over = self.isOver(w, noteSkin.unit, x, 0)
	over = self.mouseOver("add note" .. columnIndex, over, "mouse")
	return {
		columnIndex = columnIndex,
		time = time,
		over = over,
		leftPressed = inputState.leftPressed,
	}
end

---@param inputState rizu.editor.EditorPlayfieldInputState
---@return rizu.editor.EditorPlayfieldSelectInput
function EditorPlayfieldHitTestService:getSelectInput(inputState)
	return {
		over = self.mouseOver("editor select", true, "mouse"),
		leftPressed = inputState.leftPressed,
	}
end

---@param mouseTime number
---@param inputState rizu.editor.EditorPlayfieldInputState
---@return rizu.editor.EditorPlayfieldReleaseInput
function EditorPlayfieldHitTestService:getReleaseInput(mouseTime, inputState)
	return {
		leftReleased = inputState.leftReleased,
		mouseTime = mouseTime,
	}
end

return EditorPlayfieldHitTestService
