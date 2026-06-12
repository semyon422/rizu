local class = require("class")

---@class rizu.editor.EditorScrollInputState
---@field showMouseDelta boolean

---@class rizu.editor.EditorScrollInputFrame
---@field mouseY number
---@field dragActive boolean
---@field scroll number?

---@class rizu.editor.EditorScrollInputService
---@operator call: rizu.editor.EditorScrollInputService
---@field prevMouseY number
---@field originalSpeed number?
local EditorScrollInputService = class()

function EditorScrollInputService:new()
	self.prevMouseY = 0
end

---@param editorModel rizu.editor.EditorModel
---@param noteSkin table
---@param editor table
---@param frame rizu.editor.EditorScrollInputFrame
---@return rizu.editor.EditorScrollInputState
function EditorScrollInputService:update(editorModel, noteSkin, editor, frame)
	local fineScroll = editorModel.isFineScrollRequested()
	local snapChange = editorModel.isSnapChangeRequested()
	local speedChange = editorModel.isSpeedChangeRequested()

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
		editorModel.scroller:scrollSecondsDelta((currentYTime - prevYTime) / editor.speed)
		if editorModel.timer.is_playing then
			editorModel:pause()
			editorModel.session.dragging = true
		end
	elseif editorModel.session.dragging then
		editorModel:play()
		editorModel.session.dragging = false
	end
	self.prevMouseY = frame.mouseY

	local scroll = frame.scroll
	if scroll then
		if snapChange then
			if scroll == 1 then
				editorModel:incSnap()
			elseif scroll == -1 then
				editorModel:decSnap()
			end
		elseif speedChange then
			editorModel:setLogSpeed(editorModel:getLogSpeed() + scroll)
		else
			if editorModel.timer.is_playing and scroll < 0 then
				editorModel.scroller:scrollSnaps(scroll)
			end
			editorModel.scroller:scrollSnaps(scroll)
		end
	end

	return {
		showMouseDelta = fineScroll or snapChange or speedChange,
	}
end

return EditorScrollInputService
