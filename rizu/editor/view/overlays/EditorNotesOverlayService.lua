local class = require("class")

---@class rizu.editor.EditorNoteSettings
---@field snap integer
---@field lockSnap boolean
---@field tool string

---@class rizu.editor.EditorNoteSound
---@field [1] string

---@class rizu.editor.EditorNoteWithSounds
---@field sounds rizu.editor.EditorNoteSound[]?

---@class rizu.editor.SelectedEditorNote
---@field startNote rizu.editor.EditorNoteWithSounds

---@class rizu.editor.EditorNotesOverlayState
---@field logSpeed number
---@field snap integer
---@field lockSnap boolean
---@field tool string
---@field maxSnap integer
---@field tools string[]
---@field toolHotkeys string[]
---@field toolHotkeyLabel string
---@field logSpeedLabel string
---@field snapLabel string
---@field hasSelectedNotes boolean
---@field selectedNoteSound string?

---@class rizu.editor.EditorNotesOverlayInput
---@field logSpeed number
---@field snap integer
---@field lockSnap boolean
---@field tool string
---@field pressedHotkeys {[string]: boolean}

---@class rizu.editor.EditorNotesOverlayContext
---@field getLogSpeed fun(self: rizu.editor.EditorNotesOverlayContext): number
---@field setLogSpeed fun(self: rizu.editor.EditorNotesOverlayContext, logSpeed: number)
---@field getEditorSettings fun(self: rizu.editor.EditorNotesOverlayContext): rizu.editor.EditorNoteSettings
---@field getMaxSnap fun(self: rizu.editor.EditorNotesOverlayContext): integer
---@field getTools fun(self: rizu.editor.EditorNotesOverlayContext): string[]
---@field getSelectedNotes fun(self: rizu.editor.EditorNotesOverlayContext): {[chart.Note]: rizu.editor.SelectedEditorNote}

---@class rizu.editor.EditorNotesOverlayService
---@operator call: rizu.editor.EditorNotesOverlayService
local EditorNotesOverlayService = class()

EditorNotesOverlayService.toolHotkeys = {"q", "w", "e", "r", "t", "y"}

---@param context rizu.editor.EditorNotesOverlayContext
---@return rizu.editor.EditorNotesOverlayState
function EditorNotesOverlayService:getState(context)
	local editor = context:getEditorSettings()
	local _, selectedNote = next(context:getSelectedNotes())
	---@type string?
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
		toolHotkeys = self:getToolHotkeys(context:getTools()),
		toolHotkeyLabel = self:getToolHotkeyLabel(context:getTools()),
		logSpeedLabel = "speed " .. context:getLogSpeed(),
		snapLabel = "snap " .. editor.snap,
		hasSelectedNotes = selectedNote ~= nil,
		selectedNoteSound = selectedNoteSound,
	}
end

---@param tools string[]
---@return string[]
function EditorNotesOverlayService:getToolHotkeys(tools)
	---@type string[]
	local hotkeys = {}
	local max = math.min(#tools, #self.toolHotkeys)
	for i = 1, max do
		hotkeys[i] = self.toolHotkeys[i]
	end
	return hotkeys
end

---@param tools string[]
---@return string
function EditorNotesOverlayService:getToolHotkeyLabel(tools)
	---@type string[]
	local labels = {}
	for i, key in ipairs(self:getToolHotkeys(tools)) do
		labels[i] = ("%s:%s"):format(key, tools[i])
	end
	return "Use " .. table.concat(labels, " ")
end

---@param context rizu.editor.EditorNotesOverlayContext
---@param state rizu.editor.EditorNotesOverlayState
---@param input rizu.editor.EditorNotesOverlayInput
function EditorNotesOverlayService:handleInput(context, state, input)
	if input.logSpeed ~= state.logSpeed then
		self:setLogSpeed(context, input.logSpeed)
	end

	self:setSnap(context, input.snap)
	self:setLockSnap(context, input.lockSnap)
	self:setTool(context, input.tool)

	for _, key in ipairs(state.toolHotkeys) do
		if input.pressedHotkeys[key] then
			self:setToolForHotkey(context, key)
		end
	end
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
	---@type integer?
	local index
	for i, toolKey in ipairs(self.toolHotkeys) do
		if toolKey == key then
			index = i
			break
		end
	end
	if not index or index > #tools then
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
