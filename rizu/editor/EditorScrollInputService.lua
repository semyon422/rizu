local class = require("class")

---@class rizu.editor.EditorScrollInputState
---@field showMouseDelta boolean

---@class rizu.editor.EditorScrollInputFrame
---@field mouseY number
---@field dragActive boolean
---@field scroll number?

---@class rizu.editor.EditorScrollInputContext
---@field isFineScrollRequested fun(self: rizu.editor.EditorScrollInputContext): boolean
---@field isSnapChangeRequested fun(self: rizu.editor.EditorScrollInputContext): boolean
---@field isSpeedChangeRequested fun(self: rizu.editor.EditorScrollInputContext): boolean
---@field scrollSecondsDelta fun(self: rizu.editor.EditorScrollInputContext, delta: number)
---@field scrollSnaps fun(self: rizu.editor.EditorScrollInputContext, scroll: number)
---@field isPlaying fun(self: rizu.editor.EditorScrollInputContext): boolean
---@field play fun(self: rizu.editor.EditorScrollInputContext)
---@field pause fun(self: rizu.editor.EditorScrollInputContext)
---@field isDragging fun(self: rizu.editor.EditorScrollInputContext): boolean
---@field setDragging fun(self: rizu.editor.EditorScrollInputContext, dragging: boolean)
---@field incSnap fun(self: rizu.editor.EditorScrollInputContext)
---@field decSnap fun(self: rizu.editor.EditorScrollInputContext)
---@field getLogSpeed fun(self: rizu.editor.EditorScrollInputContext): number
---@field setLogSpeed fun(self: rizu.editor.EditorScrollInputContext, logSpeed: number)

---@class rizu.editor.EditorScrollInputService
---@operator call: rizu.editor.EditorScrollInputService
---@field prevMouseY number
---@field originalSpeed number?
local EditorScrollInputService = class()

function EditorScrollInputService:new()
	self.prevMouseY = 0
end

---@param context rizu.editor.EditorScrollInputContext
---@param noteSkin table
---@param editor table
---@param frame rizu.editor.EditorScrollInputFrame
---@return rizu.editor.EditorScrollInputState
function EditorScrollInputService:update(context, noteSkin, editor, frame)
	local fineScroll = context:isFineScrollRequested()
	local snapChange = context:isSnapChangeRequested()
	local speedChange = context:isSpeedChangeRequested()

	if fineScroll and not self.originalSpeed then
		self.originalSpeed = editor.speed
		editor.speed = 1000 / noteSkin.unit * 10
	elseif not fineScroll and self.originalSpeed then
		editor.speed = self.originalSpeed
		self.originalSpeed = nil
	end

	if (fineScroll or snapChange) and frame.dragActive then
		local currentYTime = noteSkin:getInverseTimePosition(frame.mouseY)
		local prevYTime = noteSkin:getInverseTimePosition(self.prevMouseY)
		context:scrollSecondsDelta((currentYTime - prevYTime) / editor.speed)
		if context:isPlaying() then
			context:pause()
			context:setDragging(true)
		end
	elseif context:isDragging() then
		context:play()
		context:setDragging(false)
	end
	self.prevMouseY = frame.mouseY

	local scroll = frame.scroll
	if scroll then
		if snapChange then
			if scroll == 1 then
				context:incSnap()
			elseif scroll == -1 then
				context:decSnap()
			end
		elseif speedChange then
			context:setLogSpeed(context:getLogSpeed() + scroll)
		else
			if context:isPlaying() and scroll < 0 then
				context:scrollSnaps(scroll)
			end
			context:scrollSnaps(scroll)
		end
	end

	return {
		showMouseDelta = fineScroll or snapChange or speedChange,
	}
end

return EditorScrollInputService
