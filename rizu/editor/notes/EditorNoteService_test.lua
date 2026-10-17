local EditorNoteService = require("rizu.editor.notes.EditorNoteService")
local EditorTestFactory = require("rizu.editor.test.EditorTestFactory")

local test = {}

---@param calls string[]
---@param name string
---@return table
local function createSubservice(calls, name)
	return {
		grabbedNotes = {name .. "-grabbed"},
		copiedNotes = {name .. "-copied"},
		setContext = function(self, context)
			self.context = context
			table.insert(calls, name .. ":context")
		end,
		update = function()
			table.insert(calls, name .. ":update")
		end,
		getGrabbedNotes = function(self)
			return self.grabbedNotes
		end,
		getCopiedNotes = function(self)
			return self.copiedNotes
		end,
		copy = function(_, cut)
			table.insert(calls, name .. ":copy:" .. tostring(cut))
		end,
		deleteSelected = function()
			table.insert(calls, name .. ":delete")
			return 2
		end,
		changeSelectedType = function()
			table.insert(calls, name .. ":change")
		end,
		paste = function()
			table.insert(calls, name .. ":paste")
		end,
		grab = function(_, part, mouseTime)
			table.insert(calls, ("%s:grab:%s:%s"):format(name, part, mouseTime))
		end,
		drop = function(_, mouseTime)
			table.insert(calls, name .. ":drop:" .. mouseTime)
		end,
		removeNote = function(_, note)
			table.insert(calls, name .. ":remove:" .. note.id)
		end,
		addNote = function(_, absoluteTime, column)
			table.insert(calls, ("%s:add:%s:%s"):format(name, absoluteTime, column))
		end,
		flipSelected = function()
			table.insert(calls, name .. ":flip")
		end,
	}
end

---@param t testing.T
function test.uses_injected_focused_services(t)
	local calls = {}
	local deps = {
		columnService = createSubservice(calls, "column"),
		commandService = createSubservice(calls, "command"),
		dragService = createSubservice(calls, "drag"),
		clipboardService = createSubservice(calls, "clipboard"),
		createService = createSubservice(calls, "create"),
	}
	local context = {}
	local noteService = EditorNoteService(deps)

	noteService:setContext(context)
	noteService:update()
	noteService:copyNotes(true)
	t:eq(noteService:deleteNotes(), 2)
	noteService:changeType()
	noteService:pasteNotes()
	noteService:grabNotes("head", 0.25)
	noteService:dropNotes(0.5)
	noteService:removeNote({id = "note"})
	noteService:addNote(0.75, "key1")
	noteService:flipNotes()

	t:eq(deps.dragService.context, context)
	t:eq(noteService:getGrabbedNotes(), deps.dragService:getGrabbedNotes())
	t:eq(noteService:getCopiedNotes(), deps.clipboardService:getCopiedNotes())
	t:tdeq(calls, {
		"column:context",
		"command:context",
		"drag:context",
		"clipboard:context",
		"create:context",
		"drag:update",
		"clipboard:copy:true",
		"command:delete",
		"command:change",
		"clipboard:paste",
		"drag:grab:head:0.25",
		"drag:drop:0.5",
		"command:remove:note",
		"create:add:0.75:key1",
		"command:flip",
	})
end

---@param t testing.T
function test.constructs_focused_services(t)
	local editorModel = EditorTestFactory.createEditorModel()
	local noteService = editorModel.noteService

	t:ne(noteService.columnService, nil)
	t:ne(noteService.createService, nil)
	t:ne(noteService.commandService, nil)
	t:ne(noteService.clipboardService, nil)
	t:ne(noteService.dragService, nil)
	t:eq(type(noteService.clipboardService.context.getSelectedNotes), "function")
	t:eq(noteService.clipboardService.context:getEditorChanges(), editorModel.editorChanges)
	t:eq(type(noteService.dragService.context.getSelectedNotes), "function")
	t:eq(noteService.dragService.context:getEditorChanges(), editorModel.editorChanges)
	t:eq(type(noteService.createService.context.getSettings), "function")
	t:eq(noteService.createService.context:getEditorNoteContext():getLayer(), editorModel.layer)
	t:eq(type(noteService.columnService.context.getMousePosition), "function")
	t:eq(noteService.columnService.context:getNoteSkin(), editorModel:getNoteSkin())
	t:eq(noteService.grabbedNotes, nil)
	t:eq(noteService.copiedNotes, nil)
end

---@param t testing.T
function test.copy_paste_accesses_clipboard_service_state(t)
	local editorModel = EditorTestFactory.createEditorModel()
	EditorTestFactory.addSelectedNote(editorModel, "tap", 0.25, "key1")

	editorModel.noteService:copyNotes()

	t:eq(#editorModel.noteService:getCopiedNotes(), 1)
	t:eq(editorModel.noteService:getCopiedNotes(), editorModel.noteService.clipboardService.copiedNotes)
end

---@param t testing.T
function test.get_grabbed_notes_accesses_drag_service_state(t)
	local editorModel = EditorTestFactory.createEditorModel()
	editorModel.settings.tool = "ShortNote"
	editorModel.settings.lockSnap = false
	editorModel.mouseTime = 0.25
	editorModel.noteService.columnService.columnOver = 1

	editorModel.noteService:addNote(0.25, "key1")

	t:eq(#editorModel.noteService:getGrabbedNotes(), 1)
	t:eq(editorModel.noteService:getGrabbedNotes(), editorModel.noteService.dragService.grabbedNotes)
end

---@param t testing.T
function test.delete_change_flip_delegate_to_command_service(t)
	local editorModel = EditorTestFactory.createEditorModel()
	EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.25, "key1")

	t:eq(editorModel.noteService:deleteNotes(), 1)
	editorModel.editorChanges:undo()
	t:eq(#EditorTestFactory.getNotes(editorModel), 1)

	editorModel = EditorTestFactory.createEditorModel()
	EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.5, "key1")

	editorModel.noteService:changeType()
	t:eq(#EditorTestFactory.getNotes(editorModel), 2)

	editorModel = EditorTestFactory.createEditorModel()
	EditorTestFactory.addCommittedSelectedNote(editorModel, "tap", 0.5, "key1")

	editorModel.noteService:flipNotes()
	t:eq(EditorTestFactory.getNotes(editorModel)[1].column, "key4")
end

return test
