local class = require("class")

---@class yi.views.editor.EditorNotesOverlayPanel
---@operator call: yi.views.editor.EditorNotesOverlayPanel
---@field batchComment string
local EditorNotesOverlayPanel = class()

function EditorNotesOverlayPanel:new()
	self.batchComment = ""
end

---@param screen table
---@param panel yi.views.editor.EditorOverlayPanel
---@param overlayContext rizu.editor.EditorViewContext
function EditorNotesOverlayPanel:draw(screen, panel, overlayContext)
	local notesOverlayService = screen.editorViewServices.notesOverlayService
	local notesState = notesOverlayService:getState(overlayContext)

	local logSpeed = panel:slider("editor speed", notesState.logSpeed, -30, 50, 1, "speed " .. notesState.logSpeed)
	if logSpeed ~= notesState.logSpeed then
		notesOverlayService:setLogSpeed(overlayContext, logSpeed)
	end
	notesOverlayService:setSnap(
		overlayContext,
		panel:slider("snap select", notesState.snap, 1, notesState.maxSnap, 1, "snap " .. notesState.snap)
	)
	notesOverlayService:setLockSnap(
		overlayContext,
		panel:checkbox("lock snap", notesState.lockSnap, "lock snap")
	)
	notesOverlayService:setTool(
		overlayContext,
		panel:combo("tool select", notesState.tool, notesState.tools)
	)
	panel:text("Use qwer to select tool")

	for i = 1, #notesState.tools do
		local key = ("qwerty"):sub(i, i)
		if panel:consumeKey(key) then
			notesOverlayService:setToolForHotkey(overlayContext, key)
		end
	end

	if panel:button("changeType", "change type") then
		screen.editorViewServices.overlayActionService:changeSelectedNoteType(overlayContext)
	end

	if notesState.hasSelectedNotes and panel:button("scroll to note", "scroll to") then
		screen.editorViewServices.overlayActionService:scrollToFirstSelectedNote(overlayContext)
	end

	panel:separator()

	self.batchComment = panel:input("vps comment", self.batchComment, "comment")
	if panel:button("save comment notes", "save") then
		screen.editorViewServices.overlayActionService:setSelectedNotesComment(overlayContext, self.batchComment)
	end
	if panel:button("reset comment notes", "reset") then
		screen.editorViewServices.overlayActionService:resetSelectedNotesComment(overlayContext)
	end

	if notesState.selectedNoteSound then
		panel:text(notesState.selectedNoteSound)
	end
end

return EditorNotesOverlayPanel
