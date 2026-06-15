local View = require("gui.View")
local EditorPlayfieldHitTestService = require("rizu.editor.EditorPlayfieldHitTestService")
local EditorPlayfieldInputService = require("rizu.editor.EditorPlayfieldInputService")
local EditorPlayfieldService = require("rizu.editor.EditorPlayfieldService")
local gfx_util = require("gfx_util")

---@class yi.views.editor.EditorPlayfieldView: gui.View
---@operator call: yi.views.editor.EditorPlayfieldView
---@field screen table
---@field playfieldService rizu.editor.EditorPlayfieldService
---@field playfieldInputService rizu.editor.EditorPlayfieldInputService
---@field playfieldHitTestService rizu.editor.EditorPlayfieldHitTestService
---@field leftPressed boolean
---@field rightPressed boolean
---@field leftReleased boolean
local EditorPlayfieldView = View + {}

---@param screen table
function EditorPlayfieldView:new(screen)
	View.new(self)
	self.screen = screen
	self.playfieldService = EditorPlayfieldService()
	self.playfieldInputService = EditorPlayfieldInputService({
		playfieldService = self.playfieldService,
	})
	self.playfieldHitTestService = EditorPlayfieldHitTestService()
	self.leftPressed = false
	self.rightPressed = false
	self.leftReleased = false
	self.handles_mouse_input = true
	self:setSize(love.graphics.getDimensions())
end

function EditorPlayfieldView:load()
	self:setSize(love.graphics.getDimensions())
end

---@param screen_x number
---@param screen_y number
---@return boolean
function EditorPlayfieldView:isMouseOver(screen_x, screen_y)
	local noteSkin = self.screen.game.noteSkinModel.noteSkin
	local transform = gfx_util.transform(self.screen.transform)
	local x, y = transform:inverseTransformPoint(screen_x, screen_y)
	return x >= noteSkin.baseOffset and x <= noteSkin.baseOffset + noteSkin.fullWidth and y >= 0
end

---@param e gui.MouseDownEvent
function EditorPlayfieldView:onMouseDown(e)
	if e.button == 1 then
		self.leftPressed = true
	elseif e.button == 2 then
		self.rightPressed = true
	end
	return true
end

---@param e gui.MouseUpEvent
function EditorPlayfieldView:onMouseUp(e)
	if e.button == 1 then
		self.leftReleased = true
	end
	return true
end

---@return rizu.editor.EditorPlayfieldInputState
function EditorPlayfieldView:getInputState()
	return {
		leftPressed = self.leftPressed,
		rightPressed = self.rightPressed,
		leftReleased = self.leftReleased,
	}
end

function EditorPlayfieldView:clearInputState()
	self.leftPressed = false
	self.rightPressed = false
	self.leftReleased = false
end

---@param note sphere.GraphicalNote
---@param context rizu.editor.EditorPlayfieldContext
---@param inputState rizu.editor.EditorPlayfieldInputState
function EditorPlayfieldView:processNote(note, context, inputState)
	local editorModel = self.screen.game.editorModel

	local noteInput = self.playfieldHitTestService:getNoteInput(note, editorModel:getMouseTime(), inputState)
	if noteInput then
		self.playfieldInputService:handleNoteInput(context, noteInput)
	end
end

---@param context rizu.editor.EditorPlayfieldContext
---@param inputState rizu.editor.EditorPlayfieldInputState
function EditorPlayfieldView:processColumnInputs(context, inputState)
	if not self.playfieldService:canAddNote(context) then
		return
	end

	local editorModel = self.screen.game.editorModel
	local noteSkin = self.screen.game.noteSkinModel.noteSkin
	local Head = noteSkin.notes.ShortNote.Head
	for i = 1, noteSkin.columnsCount do
		local h = noteSkin:getValue(Head.h, 1)
		local columnInput = self.playfieldHitTestService:getColumnInput(
			noteSkin,
			Head,
			i,
			editorModel:getMouseTime(h / 2),
			inputState
		)
		self.playfieldInputService:handleColumnInput(context, columnInput)
	end
end

---@param context rizu.editor.EditorPlayfieldContext
---@param inputState rizu.editor.EditorPlayfieldInputState
function EditorPlayfieldView:processSelectInput(context, inputState)
	if not self.playfieldService:isSelectTool(context) then
		return
	end

	self.playfieldInputService:handleSelectInput(
		context,
		self.playfieldHitTestService:getSelectInput(inputState)
	)
end

---@param context rizu.editor.EditorPlayfieldContext
function EditorPlayfieldView:drawSelectionRect(context)
	local selectRect = self.playfieldService:getSelectionRect(context)
	if not selectRect then
		return
	end

	local x, y, x1, y1 = unpack(selectRect)
	love.graphics.push("all")
	love.graphics.replaceTransform(gfx_util.transform(self.screen.transform))
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("line", x, y, x1 - x, y1 - y)
	love.graphics.setColor(1, 1, 1, 0.2)
	love.graphics.rectangle("fill", x, y, x1 - x, y1 - y)
	love.graphics.pop()
end

function EditorPlayfieldView:draw()
	local editorModel = self.screen.game.editorModel
	local context = editorModel.context:getViewContext()
	local inputState = self:getInputState()

	if not editorModel.layer.points:getFirstPoint() then
		self:clearInputState()
		return
	end

	if self.playfieldService:isNotesActive(context) then
		self:processColumnInputs(context, inputState)
		self:processSelectInput(context, inputState)
		self:drawSelectionRect(context)

		for _, note in ipairs(editorModel.visualEngine.notes) do
			self:processNote(note, context, inputState)
		end
		self.playfieldInputService:handleReleaseInput(
			context,
			self.playfieldHitTestService:getReleaseInput(editorModel:getMouseTime(), inputState)
		)
	end

	self:clearInputState()
end

return EditorPlayfieldView
