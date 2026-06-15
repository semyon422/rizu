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
---@field leftDown boolean
---@field rightDown boolean
local EditorPlayfieldView = View + {}

---@param screen table
function EditorPlayfieldView:new(screen)
	View.new(self)
	self.screen = screen
	screen.editor_playfield_view = self
	self.playfieldService = EditorPlayfieldService()
	self.playfieldInputService = EditorPlayfieldInputService({
		playfieldService = self.playfieldService,
	})
	self.playfieldHitTestService = EditorPlayfieldHitTestService({
		isOver = function(w, h, x, y)
			local transform = gfx_util.transform(self.screen.transform)
			local mx, my = transform:inverseTransformPoint(love.mouse.getPosition())
			x = x or 0
			y = y or 0
			return mx >= x and mx <= x + w and my >= y and my <= y + h
		end,
	})
	self.leftPressed = false
	self.rightPressed = false
	self.leftReleased = false
	self.leftDown = false
	self.rightDown = false
	self.handles_mouse_input = true
	self:setSize(love.graphics.getDimensions())
end

function EditorPlayfieldView:update()
	local x, y = love.mouse.getPosition()
	local over = self:isMouseOver(x, y)
	local leftDown = love.mouse.isDown(1)
	local rightDown = love.mouse.isDown(2)

	if over and leftDown and not self.leftDown then
		self.leftPressed = true
	end
	if over and rightDown and not self.rightDown then
		self.rightPressed = true
	end
	if not leftDown and self.leftDown then
		self.leftReleased = true
	end

	self.leftDown = leftDown
	self.rightDown = rightDown
end

---@param event table
function EditorPlayfieldView:receive(event)
	if event.name == "mousepressed" then
		local x, y = love.mouse.getPosition()
		if self:isMouseOver(x, y) then
			self:onMouseDown({
				x = x,
				y = y,
				button = event[3],
			})
		end
	elseif event.name == "mousereleased" then
		local x, y = love.mouse.getPosition()
		self:onMouseUp({
			x = x,
			y = y,
			button = event[3],
		})
	end
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
	return
		x >= noteSkin.baseOffset - noteSkin.unit and
		x <= noteSkin.baseOffset + noteSkin.fullWidth + noteSkin.unit and
		y >= -noteSkin.unit and
		y <= noteSkin.unit * 2
end

---@return integer?
function EditorPlayfieldView:getMouseColumn()
	local x = self:getMousePosition()
	local noteSkin = self.screen.game.noteSkinModel.noteSkin
	return noteSkin:getInverseColumnPosition(x)
end

---@return number
---@return number
function EditorPlayfieldView:getMousePosition()
	local transform = gfx_util.transform(self.screen.transform)
	return transform:inverseTransformPoint(love.mouse.getPosition())
end

---@param dy number?
---@return number
function EditorPlayfieldView:getMouseTime(dy)
	dy = dy or 0
	local _mx, my = self:getMousePosition()
	local noteSkin = self.screen.game.noteSkinModel.noteSkin
	local editorModel = self.screen.game.editorModel
	local editor = editorModel:getSettings()
	return editorModel:getSessionTime() - noteSkin:getInverseTimePosition(my + dy) / editor.speed
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

---@param note rizu.editor.EditorNote
---@param context rizu.editor.EditorPlayfieldContext
---@param inputState rizu.editor.EditorPlayfieldInputState
---@return boolean handled
function EditorPlayfieldView:processNote(note, context, inputState)
	local noteInput = self.playfieldHitTestService:getNoteInput(note, self:getMouseTime(), inputState)
	if noteInput then
		context:getNoteService():setColumnOver(self:getMouseColumn())
		return self.playfieldInputService:handleNoteInput(context, noteInput)
	end
	return false
end

---@param context rizu.editor.EditorPlayfieldContext
---@param inputState rizu.editor.EditorPlayfieldInputState
---@return boolean handled
function EditorPlayfieldView:processColumnInputs(context, inputState)
	if not self.playfieldService:canAddNote(context) then
		return false
	end

	local noteSkin = self.screen.game.noteSkinModel.noteSkin
	local Head = noteSkin.notes.ShortNote.Head
	for i = 1, noteSkin.columnsCount do
		local h = noteSkin:getValue(Head.h, 1)
		local columnInput = self.playfieldHitTestService:getColumnInput(
			noteSkin,
			Head,
			i,
			self:getMouseTime(h / 2),
			inputState
		)
		columnInput.mouseTime = self:getMouseTime()
		if columnInput.over then
			context:getNoteService():setColumnOver(i)
		end
		if self.playfieldInputService:handleColumnInput(context, columnInput) then
			return true
		end
	end
	return false
end

---@param context rizu.editor.EditorPlayfieldContext
---@param inputState rizu.editor.EditorPlayfieldInputState
---@return boolean handled
function EditorPlayfieldView:processSelectInput(context, inputState)
	if not self.playfieldService:isSelectTool(context) then
		return false
	end
	local mx, my = self:getMousePosition()

	local selectInput = self.playfieldHitTestService:getSelectInput(inputState)
	selectInput.mx = mx
	selectInput.my = my
	selectInput.mouseTime = self:getMouseTime()
	return self.playfieldInputService:handleSelectInput(context, selectInput)
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
	context:getNoteService():setColumnOver(self:getMouseColumn())

	if not editorModel.layer.points:getFirstPoint() then
		self:clearInputState()
		return
	end

	if self.playfieldService:isNotesActive(context) then
		local inputHandled = false
		for _, note in ipairs(editorModel.visualEngine.notes) do
			if self:processNote(note, context, inputState) then
				inputHandled = true
				break
			end
		end
		if not inputHandled then
			inputHandled = self:processColumnInputs(context, inputState)
		end
		if not inputHandled then
			self:processSelectInput(context, inputState)
		end
		self:drawSelectionRect(context)
		self.playfieldInputService:handleReleaseInput(
			context,
			self.playfieldHitTestService:getReleaseInput(self:getMouseTime(), inputState)
		)
	end

	self:clearInputState()
end

return EditorPlayfieldView
