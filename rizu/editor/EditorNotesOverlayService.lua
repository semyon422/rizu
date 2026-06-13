local class = require("class")

---@class rizu.editor.EditorNotesOverlayState
---@field logSpeed number
---@field snap integer
---@field lockSnap boolean
---@field tool string
---@field maxSnap integer
---@field tools string[]
---@field hasSelectedNotes boolean
---@field selectedNoteSound string?

---@class rizu.editor.EditorNotesOverlayContext
---@field getLogSpeed fun(self: rizu.editor.EditorNotesOverlayContext): number
---@field setLogSpeed fun(self: rizu.editor.EditorNotesOverlayContext, logSpeed: number)
---@field getEditorSettings fun(self: rizu.editor.EditorNotesOverlayContext): table
---@field getMaxSnap fun(self: rizu.editor.EditorNotesOverlayContext): integer
---@field getTools fun(self: rizu.editor.EditorNotesOverlayContext): string[]
---@field getSelectedNotes fun(self: rizu.editor.EditorNotesOverlayContext): {[chart.Note]: rizu.editor.EditorNote}

---@class rizu.editor.EditorNotesOverlayService
---@operator call: rizu.editor.EditorNotesOverlayService
local EditorNotesOverlayService = class()

---@param context rizu.editor.EditorNotesOverlayContext
---@return rizu.editor.EditorNotesOverlayState
function EditorNotesOverlayService:getState(context)
	local editor = context:getEditorSettings()
	local _, selectedNote = next(context:getSelectedNotes())
	local selectedNoteSound
	if selectedNote then
		local sounds = selectedNote.startNote.sounds
		if sounds and sounds[1] then
			selectedNoteSound = sounds[1][1]
		end
	end

	return {
		logSpeed = context:getLogSpeed(),
		snap = editor.snap,
		lockSnap = editor.lockSnap,
		tool = editor.tool,
		maxSnap = context:getMaxSnap(),
		tools = context:getTools(),
		hasSelectedNotes = selectedNote ~= nil,
		selectedNoteSound = selectedNoteSound,
	}
end

---@param context rizu.editor.EditorNotesOverlayContext
---@param logSpeed number
function EditorNotesOverlayService:setLogSpeed(context, logSpeed)
	context:setLogSpeed(logSpeed)
end

---@param context rizu.editor.EditorNotesOverlayContext
---@param snap integer
function EditorNotesOverlayService:setSnap(context, snap)
	context:getEditorSettings().snap = snap
end

---@param context rizu.editor.EditorNotesOverlayContext
---@param lockSnap boolean
function EditorNotesOverlayService:setLockSnap(context, lockSnap)
	context:getEditorSettings().lockSnap = lockSnap
end

---@param context rizu.editor.EditorNotesOverlayContext
---@param tool string
function EditorNotesOverlayService:setTool(context, tool)
	context:getEditorSettings().tool = tool
end

---@param tools string[]
---@param key string
---@return string?
function EditorNotesOverlayService:getToolForHotkey(tools, key)
	local index = ("qwerty"):find(key, 1, true)
	if not index then
		return nil
	end
	return tools[index]
end

---@param context rizu.editor.EditorNotesOverlayContext
---@param key string
---@return boolean changed
function EditorNotesOverlayService:setToolForHotkey(context, key)
	local tool = self:getToolForHotkey(context:getTools(), key)
	if not tool then
		return false
	end
	self:setTool(context, tool)
	return true
end

return EditorNotesOverlayService
